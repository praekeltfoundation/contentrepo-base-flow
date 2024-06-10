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

```stack
trigger(on: "MESSAGE RECEIVED") when has_only_phrase(event.message.text.body, "forms")

```

<!--
 dictionary: "config"
version: "0.1.0"
columns: [] 
-->

| Key             | Value                                    |
| --------------- | ---------------------------------------- |
| api_token       | xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx |
| assessment_slug | test-form                                |
| assessment_tag  | test-form                                |

```stack
card GetAssessment, then: CheckEnd do
  log("Fetching assessment @config.items.assessment_slug")

  response =
    get("https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/assessment/",
      timeout: 5_000,
      cache_ttl: 60_000,
      query: [
        ["tag", "@config.items.assessment_tag"]
      ],
      headers: [
        ["content-type", "application/json"],
        ["authorization", "Token @config.items.api_token"]
      ]
    )

  assessment_data = response.body.results[0]
  questions = assessment_data["questions"]
  question_num = 0
  score = 0

  # A user can respond with a keyword such as "why" or "explain" to
  # know the reason why asked a question. 
  # We store a list of possible keyword iterations to handle typos
  keywords = ["why", "wy", "wh", "explain", "expain", "eplain"]

  log("Starting assessment @config.items.assessment_slug")
  write_result("assessment_start", "@config.items.assessment_slug")
end

```

```stack
card CheckEnd when question_num == count(questions), then: End do
  # Because all of the guards for a card get evaluated at the same time, we have to first check if we
  # have any more questions, before we can assume that there's a question that we can access the
  # attributes of, and we have to do this in a separate CheckEnd card before the DisplayQuestion card
  log("End of assessment, score: @score")
  write_result("assessment_end", "@assessment_data.slug")
  write_result("assessment_score", "@score")
end

card CheckEnd do
  then(DisplayQuestion)
end

card DisplayQuestion when count(questions[question_num].answers) > 3, then: QuestionError do
  # For more than 3 options, use a list
  question = questions[question_num]

  question_response =
    list("Select option", QuestionResponse, map(question.answers, &[&1.answer, &1.answer])) do
      text("@question.question")
    end
end

card DisplayQuestion when questions[question_num].question_type == "age_question",
  then: ValidateAge do
  # Display the Age Question type
  question = questions[question_num]

  age = ask("@question.question")
end

card DisplayQuestion, then: QuestionError do
  # For up to 3 options, use buttons 
  question = questions[question_num]

  question_response =
    buttons(QuestionResponse, map(question.answers, &[&1.answer, &1.answer])) do
      text("@question.question")
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

card AgeExplainer, then: DisplayQuestion do
  explainer =
    if(
      is_nil_or_empty(question.explainer),
      "*Explainer:* There's no explainer for this.",
      question.explainer
    )

  text("@explainer")
end

card QuestionError when has_all_members(keywords, [@question_response]), then: DisplayQuestion do
  explainer =
    if(
      is_nil_or_empty(question.explainer),
      "*Explainer:* There's no explainer for this.",
      concatenate("*Explainer:*", " ", question.explainer)
    )

  text("@explainer")
end

card QuestionError, then: DisplayQuestion do
  # If we have an error for this question, then use that, otherwise use the generic one
  error = if(is_nil_or_empty(question.error), assessment_data.generic_error, question.error)
  log("Question number is @question_num")
  log("You entered @question_response")
  text("@error")
end

```

```stack
card QuestionResponse when questions[question_num].question_type == "age_question", then: CheckEnd do
  write_result("question_num", question_num)
  write_result("answer", age)
  log("Answered @age to question @question_num")

  question_num = question_num + 1
end

card QuestionResponse, then: CheckEnd do
  answer = find(question.answers, &(&1.answer == question_response))
  write_result("question_num", question_num)
  write_result("answer", answer.answer)
  log("Answered @answer.answer to question @question_num")

  score = score + answer.score
  question_num = question_num + 1
end

```

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
        ["authorization", "Token @config.items.api_token"]
      ]
    )

  message_body = response.body.body.text.value.message
  text("@message_body")
end

```
