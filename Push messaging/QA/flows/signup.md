# Push Messaging: Signup

This flow asks the user whether they want to sign up for the testing push messaging.

If they decline, then we exit

If they accept, then we search the ordered content sets on contentrepo for the one with the profile fields specified in the config.

## Configuration

This Journey requires the `config.contentrepo_token` global variable to be set.

This Journey also requires configuration for "gender", "age", and/or "relationship" which is used to fetch the correct Ordered Content Set.

## Contact fields

* push_messaging_signup, the time when they signed up for push messages

## Flow results

* push_messaging_signup, the id of the content set that the user signed up for, or no if they didn't sign up

## Connections to other stacks

This Journey does not link to any other Journeys

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
      ],
      query: [
        ["gender", "@config.gender"],
        ["age", "@config.age"],
        ["relationship", "@config.relationship"]
      ]
    )

  contentset = contentsets.body.results[0]
end

card CompleteSignup do
  signup_time = now()
  update_contact(push_messaging_signup: "@signup_time")
  write_result("push_messaging_signup", "@contentset.id")
  text("Thank you for signing up! You will receive your first message shortly")
end

card Exit do
  write_result("push_messaging_signup", "no")
  text("Thank you! You will not be sent any messages.")
end

```