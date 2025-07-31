# Stage Based Messaging: Topics

Stage-based messaging starts by sending an SMS message to the user. When they dial the USSD number they are presented with topics relevant to their week of pregnancy.

## Configuration

This Journey requires the `config.contentrepo_token` global variable to be set.

## Contact fields

* edd, the expected due date of the user

## Flow results

None

## Connections to other stacks

None

```stack
trigger(on: "MESSAGE RECEIVED") when has_any_exact_phrase(event.message.text.body, ["0", "hi"])

```

```stack
card CalculateWeekOfPregnancy, then: GetTopics do
#   exp_year = if month(now()) > edd_date_month, do: year(now()) + 1, else: year(now())
#   exp_date = date(exp_year, edd_date_month, 1)
#   week_of_conception = datetime_add(exp_date, -40, "W")

#   current_date = now()
#   current_year = year(current_date)
#   current_month = month(current_date)
#   current_day = day(current_date)

#   given_date = week_of_conception
#   given_year = year(given_date)
#   given_month = month(given_date)
#   given_day = day(given_date)

#   year_diff = (current_year - given_year) * 365.25
#   month_diff = (current_month - given_month) * 30.4
#   day_diff = current_day - given_day

#   log("""
#   year_diff @year_diff
#   month_diff @month_diff
#   day_diff @day_diff
#   """)

#   pregnancy_in_weeks = (month_diff + year_diff + day_diff) / 7
#   pregnancy_in_weeks = split("@pregnancy_in_weeks", ".")[0]

#   log("@pregnancy_in_weeks")
    pregnancy_in_weeks = 25 # TODO: Remove this when we have a full set of content and replace it with the calc above that relies on the edd
    slug = "sbm-topics-week-" + @pregnancy_in_weeks
end


```stack
card GetTopics, then: DisplayTopics do
  slug = "sbm-topics-week-25"

  search =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/",
      query: [
        ["slug", "@slug"]
      ],
      headers: [["Authorization", "Token @global.config.contentrepo_token"]]
    )

  page_id = search.body.results[0].id

  page =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/@page_id/",
      query: [
        ["ussd", "true"],
        ["message", 1]
      ],
      headers: [["Authorization", "Token @global.config.contentrepo_token"]]
    )

  topics_message = page.body.body.text.message
  # We subtract 1 because you can't select the first message, you start there by default
  # Then there are 4 options on the first message that you can navigate to (including the end message)
  num_messages = page.body.body.total_messages - 1
end

# 
card DisplayTopics, then: DisplayTopicsError do
  question_response = ask("@topics_message")

  assertion =
    isnumber(question_response) and question_response > 0 and question_response <= num_messages
end

card DisplayTopicsError when assertion == false do
  # invalid input, ask again
  then(DisplayTopics)
end

card DisplayTopicsError do
  then(GetSpecificTopic)
end

card GetSpecificTopic, then: DisplaySpecificTopic do
  search =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/",
      query: [
        ["slug", "@slug"]
      ],
      headers: [["Authorization", "Token @global.config.contentrepo_token"]]
    )

  page_id = search.body.results[0].id

  # Add 1 because the first message was 1, options start at 2
  message_id = question_response + 1

  page =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/@page_id/",
      query: [
        ["ussd", "true"],
        ["message", "@message_id"]
      ],
      headers: [["Authorization", "Token @global.config.contentrepo_token"]]
    )

  message = page.body.body.text.message
end

card DisplaySpecificTopic when question_response < num_messages, then: DisplaySpecificTopicError do
  question_response = ask("@message")
end

card DisplaySpecificTopic do
  # End
  text("@message")
end

card DisplaySpecificTopicError when isnumber(question_response) and question_response == 1 do
  then(DisplayTopics)
end

card DisplaySpecificTopicError do
  # invalid input, ask again
  then(DisplaySpecificTopic)
end

```