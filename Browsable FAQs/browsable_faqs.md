<!--
 dictionary: "config"
version: "0.1.0"
columns: [] 
-->

| Key               | Value                                    |
| ----------------- | ---------------------------------------- |
| contentrepo_token | xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx |
| contentrepo_url   | TODO: FIX                                |

<!-- { section: "5717187d-7351-498d-a008-73fa6b29183d", x: 0, y: 0} -->

```stack
card MainMenu do
  # Main menu displays all of the index pages for the user to select from

  # TODO: replace this with URL in config once Turn has fixed the bug that changes the URL into markdown
  indexes_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/indexes/",
      headers: [
        ["Authorization", "Token @config.items.contentrepo_token"]
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
        ["Authorization", "Token @config.items.contentrepo_token"]
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
        ["Authorization", "Token @config.items.contentrepo_token"]
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
        ["Authorization", "Token @config.items.contentrepo_token"]
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
        ["Authorization", "Token @config.items.contentrepo_token"]
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
        ["Authorization", "Token @config.items.contentrepo_token"]
      ],
      query: [["whatsapp", "true"], ["message", "@message"]]
    )

  page_list_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/",
      headers: [
        ["Authorization", "Token @config.items.contentrepo_token"]
      ],
      query: [["child_of", "@content_data.body.meta.parent.id"]]
    )
end

card Exit do
  schedule_stack("5c6b568b-58ec-444f-9e34-9f23fdfc0219", in: 0)
end

```