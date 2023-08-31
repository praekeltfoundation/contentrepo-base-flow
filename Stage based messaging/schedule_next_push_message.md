<!--
 dictionary: "config"
version: "0.1.0"
columns: [] 
-->

| Key               | Value                                    |
| ----------------- | ---------------------------------------- |
| contentrepo_token | xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx |

This stack schedules the send message callback stack, at the correct time as specified on the current message of the ordered content set.

It fetches the details from the contentrepo for the user's current content set.

If there are no more messages in the content set, then it sends the user a message that they've completed the content set.

It then calculates the timestamp when the next message should be sent, according to the specified contact field and time delta specified in content repo.

<!-- { section: "c1af92c3-f489-4f4b-8182-865897f83ea1", x: 0, y: 0} -->

```stack
card GetContentSet, then: ScheduleNextMessage do
  contentset =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/orderedcontent/@contact.push_messaging_content_set/",
      headers: [
        ["Authorization", "Token @config.items.contentrepo_token"]
      ]
    )
end

card ScheduleNextMessage
     when count(contentset.body.pages) == contact.push_messaging_content_set_position do
  text("Content set complete, no more messages")
end

card ScheduleNextMessage do
  page = contentset.body.pages[contact.push_messaging_content_set_position]
  contact_field = page.contact_field

  unit =
    find(
      [["minutes", "m"], ["hours", "h"], ["days", "D"], ["months", "M"]],
      &(&1[0] == page.unit)
    )[1]

  offset = if(page.before_or_after == "before", page.time * -1, page.time * 1)

  timestamp = datetime_add(contact[contact_field], offset, unit)
  # SBM: Schedule message callback
  schedule_stack("54e7fe5d-983a-4292-a768-ca2e95466a6a", at: timestamp)
  write_result("message_scheduled_at", "@timestamp")
end

```