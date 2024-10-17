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

* push_messaging_scheduled_at, when the next message is scheduled to be sent. The name of this contact field should be changed according to the implementation, otherwise all the push messages will overwrite each other's scheduled times.
* whatsapp_profile_name, used to personalise the template sent to the user

## Flow results

* template_sent, which message template was sent
* message_sent, the message sent to the user

## Connections to other stacks

This Journey does not link to any other Journeys

```stack
card DetermineMessage when contact.push_messaging_signup >= datetime_add(now(), 5, "m") and contact.push_messaging_signup < datetime_add(now(), 10, "m"), then: GetMessage do
  # send first message
  push_messaging_content_set_position = 0
end

# Add your other conditions here

card DetermineMessage, then: GetMessage do
  # send second message
  push_messaging_content_set_position = 1
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
      query: [["gender", "@config.gender"], ["age", "@config.age"], ["relationship", "@config.relationship"]]
    )

  contentset = contentsets.body.results[0]

  contentset_item = contentset.body.pages[push_messaging_content_set_position]

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