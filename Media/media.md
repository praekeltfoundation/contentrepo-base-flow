<!--
 dictionary: "config"
version: "0.1.0"
columns: [] 
-->

| Key               | Value                                    |
| ----------------- | ---------------------------------------- |
| contentrepo_token | xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx |
| parent_page_id    | 651                                      |

<!-- { section: "6a6de1f0-3f65-48aa-93db-5b0ea7f6e5b2", x: 0, y: 0} -->

```stack
card Menu do
  page_list_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/",
      headers: [
        ["Authorization", "Token @config.items.contentrepo_token"]
      ],
      query: [["child_of", "@config.items.parent_page_id"]]
    )

  menu_items = map(page_list_data.body.results, &[&1.title, &1.title])

  selected_content_name =
    list("Select content", FetchContent, menu_items) do
      text("Hi! Please select which content you would like to view")
    end
end

card FetchContent, then: DisplayMessage do
  selected_content_id = find(page_list_data.body.results, &(&1.title == selected_content_name)).id

  content_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/pages/@selected_content_id/",
      headers: [
        ["Authorization", "Token @config.items.contentrepo_token"]
      ],
      query: [["whatsapp", "true"]]
    )

  content_data = content_data.body
end

card DisplayMessage when content_data.body.text.value.image != nil do
  image_id = content_data.body.text.value.image

  image_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/images/@image_id/",
      headers: [
        ["Authorization", "Token @config.items.contentrepo_token"]
      ]
    )

  image("@image_data.body.meta.download_url")
  text("@content_data.body.text.value.message")
end

card DisplayMessage when content_data.body.text.value.document != nil do
  document_id = content_data.body.text.value.document

  document_data =
    get(
      "https://content-repo-api-qa.prk-k8s.prd-p6t.org/api/v2/documents/@document_id/",
      headers: [
        ["Authorization", "Token @config.items.contentrepo_token"]
      ]
    )

  document("@document_data.body.meta.download_url")
  text("@content_data.body.text.value.message")
end

card DisplayMessage do
  text("@content_data")
end

```