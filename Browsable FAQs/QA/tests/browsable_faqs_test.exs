defmodule BrowsableFAQsTest do
  use FlowTester.Case

  alias FlowTester.WebhookHandler, as: WH
  alias FlowTester.WebhookHandler.FakeCMS.Content.{Image}

  defp flow_path(flow_name), do: Path.join([__DIR__, "..", "flows_json", flow_name <> ".json"])

  def setup_fake_cms(auth_token) do
    # Start the handler.
    wh_pid = start_link_supervised!({FakeCMS, %FakeCMS.Config{auth_token: auth_token}})

    topic1_index = %Index{slug: "topic-1", title: "Topic 1"}

    leaf_page = %ContentPage{
      parent: "topic-1",
      slug: "leaf-page-1",
      title: "Leaf Page 1",
      wa_messages: [
        %WAMsg{
          message: "Test leaf content page"
        }
      ]
    }

    parent_page = %ContentPage{
      parent: "topic-1",
      slug: "parent-page-1",
      title: "Parent Page 1"
    }

    nested_leaf_page = %ContentPage{
      parent: "parent-page-1",
      slug: "nested-leaf-page",
      title: "Nested Leaf Page",
      wa_messages: [
        %WAMsg{
          message: "Test nested leaf page"
        }
      ]
    }

    multiple_messages_leaf = %ContentPage{
      parent: "topic-1",
      slug: "multiple-messages-leaf",
      title: "Multiple Messages Leaf",
      wa_messages: [
        %WAMsg{message: "First message"},
        %WAMsg{message: "Second message"}
      ]
    }

    # TODO: FakeCMS support for related_pages

    media_index = %Index{slug: "media-topic", title: "Media Topic"}
    image = %Image{id: 1, title: "Test image", download_url: "https://example.org/image.jpeg"}

    # TODO: Add support for media to fakeCMS
    # media = %Media{id: 1, title: "Test media", download_url: "https://example.org/video.mp4"}

    # image_and_media = %ContentPage{
    #   parent: "media-topic",
    #   slug: "image-and-media",
    #   title: "Image and media",
    #   wa_messages: [
    #     %WAMsg{message: "Image and media", image: image.id, media: media.id}
    #   ]
    # }
    # media_page = %ContentPage{
    #   parent: "media-topic",
    #   slug: "media",
    #   title: "Media",
    #   wa_messages: [
    #     %WAMsg{message: "Media", media: media.id}
    #   ]
    # }

    image_page = %ContentPage{
      parent: "media-topic",
      slug: "image",
      title: "Image",
      wa_messages: [%WAMsg{message: "Image", image: image.id}]
    }

    assert :ok =
             FakeCMS.add_pages(wh_pid, [
               topic1_index,
               leaf_page,
               parent_page,
               nested_leaf_page,
               multiple_messages_leaf,
               media_index,
               image_page
             ])

    assert :ok = FakeCMS.add_images(wh_pid, [image])
    # assert :ok = FakeCMS.add_media(wh_pid, [media])

    # Return the adapter.
    FakeCMS.wh_adapter(wh_pid)
  end

  defp fake_cms(step, base_url, auth_token),
    do: WH.set_adapter(step, base_url, setup_fake_cms(auth_token))

  defp setup_flow() do
    auth_token = "testtoken"

    flow_path("Browsable FAQs")
    |> FlowTester.from_json!()
    |> fake_cms("https://content-repo-api-qa.prk-k8s.prd-p6t.org/", auth_token)
    |> FlowTester.set_global_dict("config", %{"contentrepo_token" => auth_token})
  end

  describe "browsable faqs" do
    test "show menu of index pages when starting the flow" do
      setup_flow()
      |> FlowTester.start()
      |> receive_message(%{
        text: "*How can I help you today?*\n-----\nSelect the topic that you're interested in.\n",
        list: {"Select topic", [{"Topic 1", "Topic 1"}, {"Media Topic", "Media Topic"}]}
      })
    end

    test "show menu of children of index page" do
      setup_flow()
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{
        text: "Topic 1\n-----\nSelect the topic you are interested in from the list\n",
        list:
          {"Select topic",
           [
             {"Leaf Page 1", "Leaf Page 1"},
             {"Parent Page 1", "Parent Page 1"},
             {"Multiple Messages Leaf", "Multiple Messages Leaf"}
           ]}
      })
    end

    test "show message content on content page leaf" do
      setup_flow()
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Leaf Page 1")
      |> receive_message(%{
        text: "Leaf Page 1\nTest leaf content page\n",
        buttons: [{"Main Menu", "Main Menu"}]
      })
    end

    test "exit to main menu when button pressed on leaf page" do
      setup_flow()
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Leaf Page 1")
      |> receive_message(%{})
      |> FlowTester.send("Main Menu")
      |> receive_message(%{text: "TODO: Exit"})
    end

    # TODO: has_children support for fake CMS
    # test "show list of child pages on parent pages" do
    #   setup_flow()
    #   |> FlowTester.start()
    #   |> receive_message(%{})
    #   |> FlowTester.send("Topic 1")
    #   |> receive_message(%{})
    #   |> FlowTester.send("Parent Page 1")
    #   |> receive_message(%{
    #     text: "...",
    #     list: {"...", []}
    #   })
    # end

    # TODO: next_message support for fake CMS
    # test "allow to page through all messages of leaf content" do
    #   setup_flow()
    #   |> FlowTester.start()
    #   |> receive_message(%{})
    #   |> FlowTester.send("Topic 1")
    #   |> receive_message(%{})
    #   |> FlowTester.send("Multiple Messages Leaf")
    #   |> receive_message(%{
    #     text: "Multiple Messages Leaf\nFirst message\n",
    #     buttons: [{"Main Menu", "Main Menu"}]
    #   })
    # end

    # TODO: Add media support to FakeCMS
    # test "give the user a choice when both image and document is present" do
    #   setup_flow()
    #   |> FlowTester.start()
    #   |> receive_message(%{})
    #   |> FlowTester.send("Media Topic")
    #   |> receive_message(%{})
    #   |> FlowTester.send("Image and media")
    #   |> receive_message(%{text: "..."})
    # end
    # test "display the media when present" do
    #   setup_flow()
    #   |> FlowTester.start()
    #   |> receive_message(%{})
    #   |> FlowTester.send("Media Topic")
    #   |> receive_message(%{})
    #   |> FlowTester.send("Media")
    #   |> receive_message(%{text: "..."})
    # end

    test "display image and return to main menu" do
      setup_flow()
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Media Topic")
      |> receive_message(%{})
      |> FlowTester.send("Image")
      |> receive_messages([
        %{text: "Image", image: "https://example.org/image.jpeg"},
        %{text: "*How can I help you today?*" <> _}
      ])
    end
  end
end
