<!--
 dictionary: "config"
version: "0.1.0"
columns: [] 
-->

| Key               | Value                                    |
| ----------------- | ---------------------------------------- |
| contentrepo_token | xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx |

This stack fetches the current message for the current message set, as defined in the contact fields.

It handles the following message types:

* Template messages. Assumes template message with two variables. Sets the first to the contact's whatsapp profile name, and the second to the literal "Second"
* Text messages. Sends the title, followed by the body, of the whatsapp message, in a single message to the user.

It then increments the content set position on the contact, and runs the stack that handles scheduling the next message in the message set.

<!-- { section: "c1af92c3-f489-4f4b-8182-865897f83ea1", x: 0, y: 0} -->

```stack
card GetMessage, then: SendMessage do
  contentset =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/orderedcontent/@contact.push_messaging_content_set/",
      headers: [
        ["Authorization", "Token @config.items.contentrepo_token"]
      ]
    )

  contentset_item = contentset.body.pages[contact.push_messaging_content_set_position]

  page =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/@contentset_item.id/",
      headers: [
        ["Authorization", "Token @config.items.contentrepo_token"]
      ],
      query: [["whatsapp", "true"]]
    )
end

card SendMessage when page.body.body.is_whatsapp_template, then: ScheduleNextMessage do
  write_result("template_sent", "@page.body.body.whatsapp_template_name")

  send_message_template("@page.body.body.whatsapp_template_name", "en_US", [
    "@contact.whatsapp_profile_name",
    "Second"
  ])
end

card SendMessage, then: ScheduleNextMessage do
  write_result("message_sent", "@page.body.id")

  text("""
  @page.body.title

  @page.body.body.text.value.message
  """)
end

card ScheduleNextMessage do
  update_contact(
    push_messaging_content_set_position: "@(contact.push_messaging_content_set_position + 1)"
  )

  # SBM: Schedule next push message
  run_stack("f7a966e0-2945-455e-a3d2-519b750e20aa")
end

```