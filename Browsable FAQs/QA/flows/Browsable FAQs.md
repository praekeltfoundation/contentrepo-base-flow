# Browsable FAQs

This Journey allows users to browse through the tree structure in the CMS, to view all of the content themselves.

# Configuration

This Journey requires the `config.contentrepo_token` global variable to be set.

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

card FetchContent, then: DisplayContent do
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

card DisplayContent when content_data.body.has_children do
  # If there are children, then give the user a list of options to choose from
  parent_body =
    if(
      count(content_data.body.body.text) > 0,
      content_data.body.body.text.value.message,
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

card DisplayContent when isnumber(content_data.body.body.next_message) do
  next_prompt = "@content_data.body.body.text.value.next_prompt"
  next_prompt = if(len(next_prompt) > 0, next_prompt, "Tell me more")
  message = content_data.body.body.next_message

  buttons(FetchContent: "@next_prompt") do
    text("""
    @content_data.body.title
    @content_data.body.body.text.value.message
    """)
  end
end

card DisplayContent when count(content_data.body.related_pages) > 0 do
  related_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/@selected_content_id/",
      headers: [
        ["Authorization", "Token @global.config.contentrepo_token"]
      ]
    )

  related_pages = map(related_data.body.related_pages, &[&1.title, &1.title])

  selected_content_name =
    list("Select related page", SelectRelatedPage, related_pages) do
      text("""
      @content_data.body.title
      @content_data.body.body.text.value.message
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
    @content_data.body.body.text.value.message
    """)
  end
end

card SelectRelatedPage, then: DisplayContent do
  selected_content_id =
    find(related_data.body.related_pages, &(&1.title == selected_content_name)).value

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
  text("@content_data.body.body.text.value.message")
end

card DisplayMedia when media_data.media_type == "audio", then: MainMenu do
  log("Media ID-2: @media_data.id")
  log("Media Type-2: @media_data.media_type")

  audio("@media_data.meta.download_url")
  text("@content_data.body.body.text.value.message")
end

card DisplayMedia when media_data.media_type == "video", then: MainMenu do
  log("Media ID-1: @media_data.id")
  log("Media Type-1: @media_data.media_type")
  log("@media_data.meta.download_url")

  video("@media_data.meta.download_url")
  text("@content_data.body.body.text.value.message")
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