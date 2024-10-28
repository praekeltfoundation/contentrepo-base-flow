```stack
# One trigger for each message that needs to be sent in OCS

trigger(interval: "+5m", relative_to: "contact.push_messaging_signup")
trigger(interval: "+10m", relative_to: "contact.push_messaging_signup")

```

This stack fetches the message to be sent based on the difference between the current time and the signup time.

It handles the following message types:

* Template messages. Assumes template message with two variables. Sets the first to the contact's whatsapp profile name, and the second to the literal "Second"
* Text messages. Sends the title, followed by the body, of the whatsapp message, in a single message to the user.

It then increments the content set position on the contact, and runs the stack that handles scheduling the next message in the message set.

## Configuration

This Journey requires the `config.contentrepo_token` global variable to be set.

This Journey also requires configuration for "gender", "age", and/or "relationship" which is used to fetch the correct Ordered Content Set.

## Contact fields

* push_messaging_signup, the time the user signed up for these messages. The name of this contact field should be changed according to the implementation, otherwise all the push messages will overwrite each other's scheduled times.
* whatsapp_profile_name, used to personalise the template sent to the user

## Flow results

* template_sent, which message template was sent
* message_sent, the message sent to the user

## Connections to other stacks

This Journey does not link to any other Journeys

## Determine message

This block figures out which message to send to the user based on the difference between the current time, and when the user signed up plus the trigger time. This way if we update CMS with a new message then the correct sequence is still followed for users partway through.

```stack
card DetermineMessage
     when now() >= datetime_add(contact.push_messaging_signup, 5, "m") and
            now() < datetime_add(contact.push_messaging_signup, 10, "m"),
     then: CalculateAge do
  # send first message
  push_messaging_content_set_position = 0
end

# Add your other conditions here

card DetermineMessage, then: CalculateAge do
  # send second message
  push_messaging_content_set_position = 1
end

```

## Calculate Age & Determine Age Range

CMS uses age ranges, so in order to filter by age, we need get the age either from the `age` contact field or calculate it from the `year_of_birth` contact field, and then determine which age range it falls into.

```stack
card CalculateAge, then: DetermineAgeRange do
  # age =
  #   if is_nil_or_empty(contact.age) do
  #     year(now()) - contact.year_of_birth
  #   else
  #     contact.age
  #   end
  # we don't currently have an age contact field and it seems silly to have to create it for
  # this journey
  age =
    if is_nil_or_empty(contact.year_of_birth) do
      0
    else
      year(now()) - contact.year_of_birth
    end
end

card DetermineAgeRange when age >= 15 and age <= 18, then: GetMessage do
  age_range = "15 - 18"
end

card DetermineAgeRange when age >= 25 and age <= 30, then: GetMessage do
  age_range = "25 - 30"
end

card DetermineAgeRange, then: GetMessage do
  age_range = ""
end

```

```stack
card GetMessage, then: SendMessage do
  contentsets =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/orderedcontent/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ],
      query: [
        ["gender", "@contact.gender"],
        ["age", "@age_range"],
        ["relationship", "@contact.relationship_status"]
      ]
    )

  contentset = contentsets.body.results[0]

  contentset_item = contentset.pages[push_messaging_content_set_position]

  page =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/@contentset_item.id/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ],
      query: [["whatsapp", "true"]]
    )
end

card SendMessage when page.body.body.is_whatsapp_template do
  write_result("template_sent", "@page.body.body.whatsapp_template_name")

  send_message_template("@page.body.body.whatsapp_template_name", "en_US", [
    "@contact.whatsapp_profile_name",
    "Second"
  ])
end

card SendMessage do
  write_result("message_sent", "@page.body.id")

  text("""
  @page.body.title

  @page.body.body.text.value.message
  """)
end

```