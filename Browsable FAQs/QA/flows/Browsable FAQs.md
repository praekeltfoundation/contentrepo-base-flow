<!-- { section: "7ac3c144-c5fa-49b9-a924-9d9e7516c428", x: 500, y: 48} -->

```stack
trigger(on: "MESSAGE RECEIVED") when has_only_phrase(event.message.text.body, "browse")

```

# Browsable FAQs

This Journey allows users to browse through the tree structure in the CMS, to view all of the content themselves.

## Configuration

This Journey requires the `config.contentrepo_token` global variable to be set.

## Contact fields

This Journey doesn't use or set any contact fields

## Flow results

This Journey doesn't write any flow results

## Connections to other stacks

When you reach the leaf of the content tree, a single "Main Menu" button appears. This needs to be linked to go back to the service's main menu.

# MainMenu

This menu displays all the titles of the index pages that are found in the CMS, along with a hardcoded message.

<!-- { section: "5717187d-7351-498d-a008-73fa6b29183d", x: 0, y: 0} -->

```stack
card MainMenu do
  # Main menu displays all of the index pages for the user to select from
  # TODO: replace this with URL in config once Turn has fixed the bug that changes the URL into markdown
  indexes_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/indexes/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ],
      query: []
    )

  # TODO: due to a bug in stacks, the ID and the title have to be the same here
  menu_items = map(indexes_data.body.results, &[&1.title, &1.title])

  selected_index_name =
    list("Select topic", IndexMenu, menu_items) do
      text("""
      *How can I help you today?*
      -----
      Select the topic that you're interested in.
      """)
    end
end

```

# IndexMenu

This card fetches all the children of the selected index page, and displays them in a list

```stack
card IndexMenu, then: FetchContent do
  # Here we fetch all the children of the selected index
  selected_index_id = filter(indexes_data.body.results, &(&1.title == selected_index_name))[0].id

  page_list_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ],
      query: [["child_of", "@selected_index_id"]]
    )

  index_menu_items = map(page_list_data.body.results, &[&1.title, &1.title])
  message = 1

  selected_content_name =
    list("Select topic", FetchContent, index_menu_items) do
      text("""
      @selected_index_name
      -----
      Select the topic you are interested in from the list
      """)
    end
end

```

# FetchContent & DisplayContent

These cards fetch the current selected content from the CMS, and displays it. It handles:

* If the content has children, it should show a list of those children
* If the content has more than one message, it should show a button to see the next message
* If there are related pages, it should show a list and allow the user to browse to a related page
* If there is an image or media file, it should display that

```stack
card FetchContent, then: GetVariation do
  selected_content_id =
    filter(page_list_data.body.results, &(&1.title == selected_content_name))[0].id

  content_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/@selected_content_id/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ],
      query: [["whatsapp", "true"], ["message", "@message"]]
    )
end

card GetVariation when count(content_data.body.body.text) > 0, then: DisplayContent do
  content_body = content_data.body.body.text.value.message
  variations = content_data.body.body.text.value.variation_messages

  # Find and apply gender variation
  gender_variations =
    filter(variations, &(&1.profile_field == "gender" and &1.value == contact.gender))

  content_body = if(count(gender_variations) > 0, gender_variations[0].message, content_body)

  # Find and apply relationship variation
  # Relationship stored on the contact is different to the one on the CMS, so translate between them
  relationship_mapping = [
    ["single", "single"],
    ["in a relationship", "in_a_relationship"],
    ["it's complicated", "complicated"],
    ["empty", ""],
    ["", ""]
  ]

  relationship_status = find(relationship_mapping, &(&1[0] == contact.relationship_status))[1]

  relationship_variations =
    filter(variations, &(&1.profile_field == "relationship" and &1.value == relationship_status))

  content_body =
    if(count(relationship_variations) > 0, relationship_variations[0].message, content_body)

  # Find and apply age variation
  # We only have year of birth, so we have to make the 1 January assumption and just difference to current year
  # Age is also stored as ranges in the CMS, so map between age and age ranges
  year_of_birth = contact.year_of_birth or ""

  age =
    if(
      isnumber(year_of_birth),
      year(now()) - year_of_birth,
      -1
    )

  age_mapping = [
    [[15, 18], "15-18"],
    [[19, 24], "19-24"]
  ]

  age_mapping_result = filter(age_mapping, &(age >= &1[0][0] and age <= &1[0][1]))
  age_range = if(count(age_mapping_result) > 0, age_mapping_result[0][1], "")
  age_variations = filter(variations, &(&1.profile_field == "age" and &1.value == age_range))
  content_body = if(count(age_variations) > 0, age_variations[0].message, content_body)
end

card GetVariation, then: DisplayContent do
  log("No messages, not searching for variations")
end

card DisplayContent when count(content_data.body.body.text.value.buttons) > 0 do
  content_buttons = content_data.body.body.text.value.buttons

  selected_button =
    buttons(ProcessButton, map(content_buttons, &[&1.value.title, &1.value.title])) do
      text("""
      @content_data.body.title
      @content_body
      """)
    end
end

card DisplayContent when content_data.body.has_children do
  # If there are children, then give the user a list of options to choose from
  parent_body =
    if(
      count(content_data.body.body.text) > 0,
      content_body,
      "Select an item"
    )

  parent_title = content_data.body.title
  selected_content_id = find(page_list_data.body.results, &(&1.title == selected_content_name)).id

  page_list_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ],
      query: [
        ["child_of", "@selected_content_id"]
      ]
    )

  content_children = map(page_list_data.body.results, &[&1.title, &1.title])

  selected_content_name =
    list("Select a topic", FetchContent, content_children) do
      text("""
      @parent_title
      -----
      @parent_body
      """)
    end
end

card DisplayContent when count(content_data.body.related_pages) > 0 do
  related_pages = map(content_data.body.related_pages, &[&1.title, &1.title])

  selected_content_name =
    list("Select related page", SelectRelatedPage, related_pages) do
      text("""
      @content_data.body.title
      @content_body
      """)
    end
end

card DisplayContent
     when isnumber(content_data.body.body.text.value.media) and
            isnumber(content_data.body.body.text.value.image) do
  # For content page that have image and media
  # Get medias in content page and add to buttons

  media_id = content_data.body.body.text.value.media
  log("Media ID Sila @media_id")

  media_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/media/@media_id/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ]
    )

  image_id = content_data.body.body.text.value.image
  log("Image ID Sila @image_id")

  image_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/images/@image_id/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ]
    )

  media_data = media_data.body
  image_data = image_data.body
  log("Data: @media_data.body")
  log("Data: @media_data.media_type == video")

  buttons(
    DisplayMedia: "view @media_data.media_type",
    DisplayImage: "view @image_data.media_type"
  ) do
    text("select an option")
  end
end

card DisplayContent when isnumber(content_data.body.body.text.value.media), then: DisplayMedia do
  # For content page that have media only
  media_id = content_data.body.body.text.value.media
  log("Media ID @media_id")

  media_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/media/@media_id/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ]
    )

  media_data = media_data.body
  log("Data: @media_data.body")
  log("Data: @media_data.media_type == video")
end

card DisplayContent when isnumber(content_data.body.body.text.value.image), then: DisplayImage do
  image_id = content_data.body.body.text.value.image
  log("Media ID @image_id")

  image_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/images/@image_id/",
      headers: [
        ["Authorization", "Token @globals.config.contentrepo_token"]
      ]
    )

  image_data = image_data.body
  log("Data: @image_data.body")
end

card DisplayContent do
  buttons(Exit: "Main Menu") do
    text("""
    @content_data.body.title
    @content_body
    """)
  end
end

card SelectRelatedPage, then: GetVariation do
  selected_content_id =
    find(content_data.body.related_pages, &(&1.title == selected_content_name)).value

  message = 1

  content_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/@selected_content_id/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ],
      query: [["whatsapp", "true"], ["message", "@message"]]
    )

  page_list_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ],
      query: [["child_of", "@content_data.body.meta.parent.id"]]
    )
end

card Exit do
  text("TODO: Exit")
  # schedule_stack("5c6b568b-58ec-444f-9e34-9f23fdfc0219", in: 0)
end

card DisplayImage, then: MainMenu do
  log("@image_data")
  log("Image ID: @image_data.id")
  log("Image Type: @image_data.media_type")

  image("@image_data.meta.download_url")
  text("@content_body")
end

card DisplayMedia when media_data.media_type == "audio", then: MainMenu do
  log("Media ID-2: @media_data.id")
  log("Media Type-2: @media_data.media_type")

  audio("@media_data.meta.download_url")
  text("@content_body")
end

card DisplayMedia when media_data.media_type == "video", then: MainMenu do
  log("Media ID-1: @media_data.id")
  log("Media Type-1: @media_data.media_type")
  log("@media_data.meta.download_url")

  video("@media_data.meta.download_url")
  text("@content_body")
end

card DisplayMedia do
  buttons(Exit: "Main Menu") do
    text("""
    @content_data.title
    @content_data.body.text.value.message
    """)
  end
end

```

# ProcessButton & ActionButton

These cards handle processing a button action that is defined in the CMS, and performing that action

```stack
card ProcessButton do
  selected_button = find(content_buttons, &(&1.value.title == selected_button))
  then(ActionButton)
end

card ActionButton when selected_button.type == "next_message" do
  message = content_data.body.body.next_message
  then(FetchContent)
end

card ActionButton when selected_button.type == "go_to_page" do
  selected_content_id = selected_button.value.page

  message = 1

  content_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/@selected_content_id/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ],
      query: [["whatsapp", "true"], ["message", "@message"]]
    )

  page_list_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ],
      query: [["child_of", "@content_data.body.meta.parent.id"]]
    )

  then(GetVariation)
end

card ActionButton do
  log("ERROR: Unknown button type @selected_button.type")
  # Cause an error
  base64_decode("ERROR: Unknown button type @selected_button.type")
end

```