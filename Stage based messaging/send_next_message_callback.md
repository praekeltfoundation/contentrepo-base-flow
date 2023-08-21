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
card SendMessage do
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

  text("""
  @page.body.title

  @page.body.body.text.value.message
  """)

  update_contact(
    push_messaging_content_set_position: "@(contact.push_messaging_content_set_position + 1)"
  )

  run_stack("f7a966e0-2945-455e-a3d2-519b750e20aa")
end

```