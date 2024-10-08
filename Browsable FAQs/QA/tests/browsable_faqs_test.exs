defmodule BrowsableFAQsTest do
  use FlowTester.Case
  use FakeCMS

  alias FlowTester.WebhookHandler, as: WH

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
          message: "Test leaf content page",
          buttons: [%Btn.Next{title: "Next"}]
        },
        %WAMsg{
          message: "Last message"
        }
      ]
    }

    tagged_leaf_page = %ContentPage{
      parent: "topic-1",
      slug: "tagged-leaf-page-1",
      title: "Tagged Leaf Page 1",
      tags: ["female"],
      wa_messages: [
        %WAMsg{
          message: "Test tagged leaf content page",
          buttons: [%Btn.Next{title: "Next"}]
        },
        %WAMsg{
          message: "Last message"
        }
      ]
    }

    parent_page = %ContentPage{
      parent: "topic-1",
      slug: "parent-page-1",
      title: "Parent Page 1",
      wa_messages: [%WAMsg{message: "Show this in whatsapp menus"}]
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
        %WAMsg{message: "First message", buttons: [%Btn.Next{title: "Next"}]},
        %WAMsg{
          message: "Second message",
          buttons: [%Btn.GoToPage{title: "Another page", page: "leaf-page-1"}]
        }
      ]
    }

    related_page_leaf = %ContentPage{
      parent: "topic-1",
      slug: "related-page-leaf",
      title: "Related Page Leaf",
      related_pages: ["multiple-messages-leaf"],
      wa_messages: [
        %WAMsg{
          message: "Test related page leaf"
        }
      ]
    }

    variations_page = %ContentPage{
      parent: "topic-1",
      slug: "variations-page",
      title: "Variations test",
      tags: ["female", "male"],
      wa_messages: [
        %WAMsg{
          message: "Default message without variations",
          variation_messages: [
            %Variation{
              profile_field: "gender",
              value: "male",
              message: "Male variation of message"
            },
            %Variation{
              profile_field: "gender",
              value: "female",
              message: "Female variation of message"
            },
            %Variation{
              profile_field: "relationship",
              value: "single",
              message: "Single variation of message"
            },
            %Variation{
              profile_field: "relationship",
              value: "in_a_relationship",
              message: "In a relationship variation of message"
            },
            %Variation{
              profile_field: "relationship",
              value: "complicated",
              message: "In a complicated relationship variation of message"
            },
            %Variation{
              profile_field: "age",
              value: "15-18",
              message: "15-18 year old variation of message"
            },
            %Variation{
              profile_field: "age",
              value: "19-24",
              message: "19-24 year old variation of message"
            }
          ]
        }
      ]
    }

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
               related_page_leaf,
               media_index,
               image_page,
               variations_page,
               tagged_leaf_page
             ])

    assert :ok = FakeCMS.add_images(wh_pid, [image])
    # assert :ok = FakeCMS.add_media(wh_pid, [media])

    # Return the adapter.
    FakeCMS.wh_adapter(wh_pid)
  end

  defp fake_cms(step, base_url, auth_token),
    do: WH.set_adapter(step, base_url, setup_fake_cms(auth_token))

  defp setup_contact_fields(context) do
    context |> FlowTester.set_contact_properties(%{"gender" => ""})
  end

  defp setup_flow() do
    auth_token = "testtoken"

    flow_path("Browsable FAQs")
    |> FlowTester.from_json!()
    |> fake_cms("https://content-repo-api-qa.prk-k8s.prd-p6t.org/", auth_token)
    |> FlowTester.set_global_dict("config", %{"contentrepo_token" => auth_token})
    |> setup_contact_fields()
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
             {"Multiple Messages Leaf", "Multiple Messages Leaf"},
             {"Related Page Leaf", "Related Page Leaf"},
             {"Variations test", "Variations test"},
             {"Tagged Leaf Page 1", "Tagged Leaf Page 1"}
           ]}
      })
    end

    test "show menu of children of index page filtered by tag" do
      setup_flow()
      |> FlowTester.set_contact_properties(%{"gender" => "female"})
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{
        text: "Topic 1\n-----\nSelect the topic you are interested in from the list\n",
        list:
          {"Select topic",
           [{"Variations test", "Variations test"}, {"Tagged Leaf Page 1", "Tagged Leaf Page 1"}]}
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
        buttons: [{"Next", "Next"}]
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
      |> FlowTester.send("Next")
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

    test "show list of buttons defined in CMS" do
      setup_flow()
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Multiple Messages Leaf")
      |> receive_message(%{
        text: "Multiple Messages Leaf\nFirst message\n",
        buttons: [{"Next", "Next"}]
      })
    end

    test "next message buttons should show the next message" do
      setup_flow()
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Multiple Messages Leaf")
      |> receive_message(%{})
      |> FlowTester.send("Next")
      |> receive_message(%{
        text: "Multiple Messages Leaf\nSecond message\n"
      })
    end

    test "go_to_page buttons should go to the specified page" do
      setup_flow()
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Multiple Messages Leaf")
      |> receive_message(%{})
      |> FlowTester.send("Next")
      |> receive_message(%{buttons: [{"Another page", "Another page"}]})
      |> FlowTester.send("Another page")
      |> receive_message(%{
        text: "Leaf Page 1\nTest leaf content page\n",
        buttons: [{"Next", "Next"}]
      })
    end

    test "next_message buttons should work after go_to_page button" do
      # Picked up by QA, DELTA-1316
      setup_flow()
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Multiple Messages Leaf")
      |> receive_message(%{})
      |> FlowTester.send("Next")
      |> receive_message(%{})
      |> FlowTester.send("Another page")
      |> receive_message(%{})
      |> FlowTester.send("Next")
      |> receive_message(%{text: "Leaf Page 1\nLast message\n"})
    end

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

    test "display related pages" do
      setup_flow()
      |> FlowTester.set_contact_properties(%{"gender" => ""})
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Related Page Leaf")
      |> receive_message(%{
        text: "Related Page Leaf\nTest related page leaf\n",
        list: {"Select related page", [{"Multiple Messages Leaf", "Multiple Messages Leaf"}]}
      })
      |> FlowTester.send("Multiple Messages Leaf")
      |> receive_message(%{
        text: "Multiple Messages Leaf\nFirst message\n",
        buttons: [{"Next", "Next"}]
      })
    end

    test "variation no gender" do
      setup_flow()
      |> FlowTester.set_contact_properties(%{"gender" => ""})
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Variations test")
      |> receive_message(%{text: "Variations test\nDefault message without variations\n"})
    end

    test "variation male" do
      setup_flow()
      |> FlowTester.set_contact_properties(%{"gender" => "male"})
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Variations test")
      |> receive_message(%{text: "Variations test\nMale variation of message\n"})
    end

    test "variation female" do
      setup_flow()
      |> FlowTester.set_contact_properties(%{"gender" => "female"})
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Variations test")
      |> receive_message(%{text: "Variations test\nFemale variation of message\n"})
    end

    test "variation relationship single" do
      setup_flow()
      |> FlowTester.set_contact_properties(%{"relationship_status" => "single"})
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Variations test")
      |> receive_message(%{text: "Variations test\nSingle variation of message\n"})
    end

    test "variation in relationship" do
      setup_flow()
      |> FlowTester.set_contact_properties(%{"relationship_status" => "in a relationship"})
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Variations test")
      |> receive_message(%{text: "Variations test\nIn a relationship variation of message\n"})
    end

    test "variation relationship complicated" do
      setup_flow()
      |> FlowTester.set_contact_properties(%{"relationship_status" => "it's complicated"})
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Variations test")
      |> receive_message(%{
        text: "Variations test\nIn a complicated relationship variation of message\n"
      })
    end

    test "variation 15-18 years old" do
      setup_flow()
      |> FlowTester.set_contact_properties(%{"year_of_birth" => "2008"})
      |> FlowTester.set_fake_time(~U[2024-01-01 00:00:00Z])
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Variations test")
      |> receive_message(%{
        text: "Variations test\n15-18 year old variation of message\n"
      })
    end

    test "variation 19-24 years old" do
      setup_flow()
      |> FlowTester.set_contact_properties(%{"year_of_birth" => "2004"})
      |> FlowTester.set_fake_time(~U[2024-01-01 00:00:00Z])
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Topic 1")
      |> receive_message(%{})
      |> FlowTester.send("Variations test")
      |> receive_message(%{
        text: "Variations test\n19-24 year old variation of message\n"
      })
    end
  end
end
