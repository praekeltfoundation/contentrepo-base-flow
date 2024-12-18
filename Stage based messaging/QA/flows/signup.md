# Stage Based Messaging: Signup

This flow asks the user whether they want to sign up for the testing stage based messaging.

If they decline, then we exit

If they accept, then we search the ordered content sets on contentrepo for one called "demo", and store the following values on the contact:

* push_messaging_signup: The timestamp when the user accepts the sign up
* push_messaging_content_set: The ID of the ordered content set named "demo"
* push_messaging_content_set_position: Start at 0, to always start at the beginning of the message set

## Configuration

This Journey requires the `config.contentrepo_token` global variable to be set.

## Contact fields

* push_messaging_signup: The timestamp when the user accepts the sign up
* push_messaging_content_set: The ID of the ordered content set named "demo"
* push_messaging_content_set_position: Start at 0, to always start at the beginning of the message set

## Flow results

* sbm_signup, whether or not the user signed up for push messages

## Connections to other stacks

* Runs the stack to schedule the next push message

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
        ["Authorization", "Token @global.config.contentrepo_token"]
      ]
    )

  contentset = find(contentsets.body.results, &(&1.name == "demo"))
end

card CompleteSignup do
  write_result("sbm_signup", "@contentset.id")
  update_contact(push_messaging_signup: "@now()")
  update_contact(push_messaging_content_set: "@contentset.id")
  update_contact(push_messaging_content_set_position: 0)
  text("Thank you for signing up! You will receive your first message shortly")
  # SBM: Schedule next push message
  run_stack("f291b782-72d3-49eb-8434-e47e388c2ea1")
end

card Exit do
  write_result("sbm_signup", "no")
  text("Thank you! You will not be sent any messages")
end

```