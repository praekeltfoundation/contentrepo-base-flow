<!-- { section: "2006d644-d5eb-4b63-9de1-bfc8d1eebc1f", x: 500, y: 48} -->

```stack
trigger(on: "MESSAGE RECEIVED") when has_only_phrase(event.message.text.body, "tform")

```

# Assessments

This Journey will fetch the assessment specified by the configured slug from ContentRepo, and run the user through the questions.

It keeps track of the score, and writes the risk category result to the flow results.

It also writes the user's answers to the flow results.

At the end of the assessment, it sends a message with the text of the page configured for that risk category.

## Content fields

This Journey does not write to any contact fields.

## Flow results

* `assessment_start` - writes the slug of the started assessment when the assessment run starts
* `question_num` - the number of the question being answered
* `answer` - the answer that the user chose
* `assessment_end` - writes the slug of the assessment when the assessment run ends
* `assessment_score` - the final score that the user got for the assessment
* `assessment_risk` - one of low, medium, or high. The final categorised risk for the user's score

## Connections to other Journeys

This Journey does not link to any other Journeys

<!--
 dictionary: "config"
version: "0.1.0"
columns: [] 
-->

| Key            | Value     |
| -------------- | --------- |
| assessment_tag | test-form |

## Get Assessment

We fetch the assessment as configured in the assessment_tag. At this point we initialise the following variables used throughout the Journey:

* `questions`, the questions to be asked in the form
* `locale`, the locale of the form
* `question_num`, the current question number
* `score`, the total assessment score, used at the end to determine which page to show the user
* `keywords`, the keywords that will trigger the explainer text

We also write the follwing flow results:

* `assessment_start`, the assessment tag
* `locale`, the locale of the form

<!-- { section: "c8467498-ead8-42c0-a1a8-e37d85ac349a", x: 0, y: 0} -->

```stack
card GetAssessment, then: CheckEnd do
  log("Fetching assessment @config.items.assessment_tag")

  response =
    get("https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/assessment/",
      timeout: 5_000,
      cache_ttl: 60_000,
      query: [
        ["tag", "@config.items.assessment_tag"]
      ],
      headers: [
        ["content-type", "application/json"],
        ["authorization", "Token @global.config.api_token"]
      ]
    )

  assessment_data = response.body.results[0]
  questions = assessment_data["questions"]
  locale = assessment_data["locale"]
  question_num = 0
  score = 0

  # A user can respond with a keyword such as "why" or "explain" to
  # know the reason why asked a question. 
  # We store a list of possible keyword iterations to handle typos
  keywords = ["why", "wy", "wh", "explain", "expain", "eplain"]

  log("Starting assessment @config.items.assessment_tag")
  write_result("assessment_start", "@config.items.assessment_tag")
  write_result("locale", "@locale")
end

```

## Display Question & Validation

1. Check if the current question is the last question
   1. If yes record the results
      * `assessment_end`, the assessment tag
      * `assessment_score`, the final score of the assessment
2. Get the question from the API response
3. Replace any variables in the question that need to be replaced
4. Display the question
5. Validate the answer and / or explain the reason for the question
6. Repeat until we reach the last question

```stack
card CheckEnd when question_num == count(questions), then: End do
  # Because all of the guards for a card get evaluated at the same time, we have to first check if we
  # have any more questions, before we can assume that there's a question that we can access the
  # attributes of, and we have to do this in a separate CheckEnd card before the DisplayQuestion card
  log("End of assessment, score: @score")
  write_result("assessment_end", "@config.items.assessment_tag")
  write_result("assessment_score", "@score")
end

card CheckEnd do
  then(GetQuestion)
end

card GetQuestion, then: DisplayQuestion do
  question = questions[question_num]
  question_text = question.question

  # Any variable replacement required can happen here
  name = if(is_nil_or_empty(contact.name), do: "", else: contact.name)
  question_text = substitute(question_text, "{{name}}", "@name")
end

# For all question types that aren't multiselect questions
card DisplayQuestion
     when questions[question_num].question_type != "multiselect_question" and
            count(questions[question_num].answers) > 3,
     then: QuestionError do
  # For more than 3 options, use a list

  question_response =
    list("Select option", QuestionResponse, map(question.answers, &[&1.answer, &1.answer])) do
      text("@question_text")
    end
end

card DisplayQuestion when questions[question_num].question_type == "age_question",
  then: ValidateAge do
  # Display the Age Question type

  age = ask("@question_text")
end

card DisplayQuestion when questions[question_num].question_type == "multiselect_question",
  then: DisplayMultiselectAnswer do
  # Display the Multiselect Question type
  answer_num = 0
  multiselect_answer = ""
end

card DisplayQuestion, then: QuestionError do
  # For up to 3 options, use buttons

  question_response =
    buttons(QuestionResponse, map(question.answers, &[&1.answer, &1.answer])) do
      text("@question_text")
    end
end

card ValidateAge when has_all_members(keywords, [@age]) == true,
  then: AgeExplainer do
end

card ValidateAge when not isnumber(age) or age > 150,
  then: QuestionError do
  log("Validatation failed for age question")
end

card ValidateAge, then: QuestionResponse do
  log("Validation suceeded for age question")
end

card AgeExplainer, then: GetQuestion do
  explainer =
    if(
      is_nil_or_empty(question.explainer),
      "*Explainer:* There's no explainer for this.",
      question.explainer
    )

  text("@explainer")
end

card QuestionError when has_all_members(keywords, [@question_response]), then: GetQuestion do
  explainer =
    if(
      is_nil_or_empty(question.explainer),
      "*Explainer:* There's no explainer for this.",
      concatenate("*Explainer:*", " ", question.explainer)
    )

  text("@explainer")
end

card QuestionError, then: GetQuestion do
  # If we have an error for this question, then use that, otherwise use the generic one
  error = if(is_nil_or_empty(question.error), assessment_data.generic_error, question.error)
  log("Question number is @question_num")
  log("You entered @question_response")
  text("@error")
end

```

## Multiselect Question

Multiselect gets a block on its own because it's essentially questions in a question. For multiselect, until we are able to use a checkbox-style input, we ask the question once for each answer that was configured, and ask the user to select `Yes`, or `No` for each answer.

The basic idea for the multiselect question is very similar to how we display questions.

1. Check if this is the last multiselect answer
   1. If yes, record the results
      * `question_num`, the question number
      * `answer`, the final answer which will be a comma separated list of all the answers that were selected
2. Get the next answer
3. Concatenate the question and answer, along with a label indicating which answer the user is on
4. Display the answer
5. If they select yes save the answer in the `multiselect_answer` variable
6. Repeat

```stack
card CheckEndMultiselect
     when questions[question_num].question_type == "multiselect_question" and
            answer_num == count(questions[question_num].answers),
     then: CheckEnd do
  question_num = question_num + 1
  # write the answer results
  write_result("question_num", question_num)
  write_result("answer", multiselect_answer)
  log("Answered @multiselect_answer to question @question_num")
end

card CheckEndMultiselect do
  then(DisplayMultiselectAnswer)
end

card DisplayMultiselectAnswer, then: MultiselectError do
  display_answer_num = answer_num + 1
  num_answers = count(question.answers)
  multiselect_question_text = "@question_text"
  answer = question.answers[answer_num]
  answer_text = answer.answer
  # Add in the Answer
  # Add in the placeholder for x / y
  multiselect_question_text =
    concatenate(
      multiselect_question_text,
      "@unichar(10)",
      "@unichar(10)",
      "@answer_text",
      "@unichar(10)",
      "@unichar(10)",
      "@display_answer_num / @num_answers"
    )

  question_response =
    buttons(MultiselectResponseYes: "Yes", MultiselectResponseNo: "No") do
      text("@multiselect_question_text")
    end
end

card MultiselectError when has_all_members(keywords, [@question_response]),
  then: DisplayMultiselectAnswer do
  explainer =
    if(
      is_nil_or_empty(question.explainer),
      "*Explainer:* There's no explainer for this.",
      concatenate("*Explainer:*", " ", question.explainer)
    )

  text("@explainer")
end

card MultiselectError, then: DisplayMultiselectAnswer do
  # If we have an error for this question, then use that, otherwise use the generic one
  error = if(is_nil_or_empty(question.error), assessment_data.generic_error, question.error)
  log("Question number is @question_num")
  log("Answer number is @answer_num")
  log("You entered @question_response")
  text("@error")
end

card MultiselectResponseYes,
  then: CheckEndMultiselect do
  answer = find(question.answers, &(&1.answer == answer_text))
  semantic_id = answer.semantic_id
  score = score + answer.score
  answer_num = answer_num + 1

  multiselect_answer =
    if is_nil_or_empty(multiselect_answer) do
      "@semantic_id"
    else
      concatenate(multiselect_answer, ",", "@semantic_id")
    end
end

card MultiselectResponseNo, then: CheckEndMultiselect do
  answer_num = answer_num + 1
end

```

## Question Response

Here we record the responses to each question.

* For freetext questions we record the full answer.
* For categorical or multiselect questions we record the semantic_id of the answer(s).

We record the following Flow Results:

* `question_num`, the question number
* `answer`, the final answer which will be a comma separated list of all the answers that were selected

```stack
card QuestionResponse when questions[question_num].question_type == "age_question", then: CheckEnd do
  write_result("question_num", question_num)
  # for freetext questions, save the answer
  write_result("answer", age)
  log("Answered @age to question @question_num")

  question_num = question_num + 1
end

# If Never is a valid response and they respond with Never, skip over everything
card QuestionResponse
     when has_member(map(question.answers, &lower(&1.answer)), "never") and
            lower("@question_response") == "never",
     then: CheckEnd do
  log("Skipping to end of Form")
  answer = find(question.answers, &(&1.answer == question_response))
  write_result("question_num", question_num)
  # for multiple choice questions, save the semantic_id
  write_result("answer", answer.semantic_id)
  log("Answered @answer.answer to question @question_num")

  score = score + answer.score
  question_num = count(questions)
end

card QuestionResponse, then: CheckEnd do
  answer = find(question.answers, &(&1.answer == question_response))
  write_result("question_num", question_num)
  # for multiple choice questions, save the semantic_id
  write_result("answer", answer.semantic_id)
  log("Answered @answer.answer to question @question_num")

  score = score + answer.score
  question_num = question_num + 1
end

```

## End

We record the final result of the Form, and display the correct End page (high, medium, low).

We record the following Flow Results:

* `assessment_risk`, `low`, `medium`, or `high` depending on the risk.

```stack
card End when score >= assessment_data.high_inflection do
  write_result("assessment_risk", "high")
  log("Assessment risk: high")
  page_id = assessment_data.high_result_page.id

  then(DisplayEndPage)
end

card End when score >= assessment_data.medium_inflection do
  write_result("assessment_risk", "medium")
  log("Assessment risk: medium")
  page_id = assessment_data.medium_result_page.id

  then(DisplayEndPage)
end

card End do
  write_result("assessment_risk", "low")
  log("Assessment risk: low")
  page_id = assessment_data.low_result_page.id

  then(DisplayEndPage)
end

card DisplayEndPage do
  response =
    get("https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/@page_id/",
      timeout: 5_000,
      cache_ttl: 60_000,
      query: [
        ["whatsapp", "true"]
      ],
      headers: [
        ["content-type", "application/json"],
        ["authorization", "Token @global.config.api_token"]
      ]
    )

  message_body = response.body.body.text.value.message
  text("@message_body")
end

```