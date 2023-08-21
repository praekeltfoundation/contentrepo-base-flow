<!--
 dictionary: "config"
version: "0.1.0"
columns: [] 
-->

| Key               | Value                                    |
| ----------------- | ---------------------------------------- |
| contentrepo_token | xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx |

<!-- { section: "c1af92c3-f489-4f4b-8182-865897f83ea1", x: 0, y: 0} -->

```stack
card AskSignup do
  buttons(FetchContentSet: "Yes, please", Exit: "No, thank you") do
    text("""
    Hi!

    Would you like to sign up to our testing messaging set?

    You will receive 5 messages, one every 5 minutes.
    """)
  end
end

card FetchContentSet, then: CompleteSignup do
  contentsets =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/orderedcontent/",
      headers: [
        ["Authorization", "Token @config.items.contentrepo_token"]
      ]
    )

  contentset = find(contentsets.body.results, &(&1.name == "demo"))
end

card CompleteSignup do
  update_contact(push_messaging_signup: "@now()")
  update_contact(push_messaging_content_set: "@contentset.id")
  update_contact(push_messaging_content_set_position: 0)
  text("Thank you for signing up! You will receive your first message shortly")
  run_stack("f7a966e0-2945-455e-a3d2-519b750e20aa")
end

card Exit do
  text("Thank you! You will not be sent any messages")
  schedule_stack("5c6b568b-58ec-444f-9e34-9f23fdfc0219", in: 0)
end

```