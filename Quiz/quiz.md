<!--
 dictionary: "config"
version: "0.1.0"
columns: [] 
-->

| Key               | Value                                    |
| ----------------- | ---------------------------------------- |
| contentrepo_token | xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx |

<!--
 table: "quizzes"
version: "0.1.0"
columns: [] 
-->

| name                    | tag             |
| ----------------------- | --------------- |
| Ready for sex           | quiz_ready_sex  |
| STIs                    | quiz_stis       |
| Consent                 | quiz_consent    |
| Alcohol                 | quiz_alcohol    |
| Coping                  | quiz_coping     |
| Relationship must haves | quiz_must_haves |
| Red flags               | quiz_red_flags  |
| Am I in ♥️?         | quiz_love       |
| Living with HIV         | quiz_hiv_life   |

<!-- { section: "6cff9aee-a67f-4288-bb1a-457b0100b149", x: 0, y: 0} -->

```stack
card QuizChoice do
  quiz_sequence = 1
  quiz_score = 0
  quiz_end = False

  quiz_titles = map(quizzes.rows, &[&1.name, &1.name])

  quiz_choice =
    list("Select quiz", SetQuizTag, quiz_titles) do
      text("Which quiz would you like to take?")
    end
end

card SetQuizTag, then: QuizQuestion do
  quiz_tag = find(quizzes.rows, &(&1.name == quiz_choice)).tag
end

card QuizQuestion, then: DisplayQuizQuestion do
  # "@quiz_tag_@quiz_sequence" doesn't work because of the "_"
  tag = concatenate(quiz_tag, "_", quiz_sequence)

  pages =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/",
      query: [
        [
          "tag",
          "@tag"
        ]
      ],
      headers: [
        [
          "Authorization",
          "Token @config.items.contentrepo_token"
        ]
      ]
    )

  page_id = pages.body.results[0].id

  page =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/@page_id/",
      query: [
        [
          "whatsapp",
          "true"
        ]
      ],
      headers: [
        [
          "Authorization",
          "Token @config.items.contentrepo_token"
        ]
      ]
    )

  page = page.body
  message = page.body.text.value.message
  quiz_end = find(page.tags, &(&1 == "quiz_end")) == "quiz_end"

  page_children =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/",
      query: [
        [
          "child_of",
          "@page_id"
        ]
      ],
      headers: [
        [
          "Authorization",
          "Token @config.items.contentrepo_token"
        ]
      ]
    )

  question_choices = map(page_children.body.results, &[&1.title, &1.title])
end

card DisplayQuizQuestion when quiz_end do
  pass_percentage = find(page.tags, &has_beginning(&1, "pass_percentage_"))
  pass_percentage = right(pass_percentage, len(pass_percentage) - 16)
  percentage = quiz_score * 100 / (quiz_sequence - 1)

  tag =
    if(
      percentage >= pass_percentage,
      concatenate("@quiz_tag", "_pass"),
      concatenate("@quiz_tag", "_fail")
    )

  pages =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/",
      query: [
        [
          "tag",
          "@tag"
        ]
      ],
      headers: [
        [
          "Authorization",
          "Token @config.items.contentrepo_token"
        ]
      ]
    )

  page_id = pages.body.results[0].id

  result_page =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/@page_id/",
      query: [
        [
          "whatsapp",
          "true"
        ]
      ],
      headers: [
        [
          "Authorization",
          "Token @config.items.contentrepo_token"
        ]
      ]
    )

  result_page = result_page.body
  result_message = result_page.body.text.value.message
  result_message = substitute(result_message, "[SCORE]", "@quiz_score")
  text("@result_message")

  buttons(MainMenu: "Main Menu") do
    text("@message")
  end
end

card MainMenu do
  schedule_stack("5c6b568b-58ec-444f-9e34-9f23fdfc0219", in: 0)
end

card DisplayQuizQuestion do
  answer =
    buttons(QuizAnswer, question_choices) do
      text("@message")
    end
end

card QuizAnswer do
  page_id = filter(page_children.body.results, &(&1.title == answer))[0].id

  page =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/@page_id/",
      query: [
        [
          "whatsapp",
          "true"
        ]
      ],
      headers: [
        [
          "Authorization",
          "Token @config.items.contentrepo_token"
        ]
      ]
    )

  page = page.body
  message = page.body.text.value.message
  quiz_sequence = quiz_sequence + 1
  answer_score = filter(page.tags, &has_beginning(&1, "score_"))
  answer_score = map(answer_score, &right(&1, len(&1) - 6))
  quiz_score = quiz_score + reduce(answer_score, 0, &(&1 + &2))

  buttons(QuizQuestion: "Next Question") do
    text("@message")
  end
end

```