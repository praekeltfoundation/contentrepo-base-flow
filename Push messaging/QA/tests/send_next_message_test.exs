defmodule SendNextMessageTest do
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
      whatsapp_template_name: "test_name",
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

    leaf_page2 = %ContentPage{
      parent: "topic-1",
      slug: "leaf-page-2",
      title: "Leaf Page 2",
      wa_messages: [
        %WAMsg{
          message: "Test leaf content page 2",
          buttons: [%Btn.Next{title: "Next"}]
        },
        %WAMsg{
          message: "Last message"
        }
      ]
    }

    leaf_page3 = %ContentPage{
      parent: "topic-1",
      slug: "leaf-page-3",
      title: "Leaf Page 3",
      whatsapp_template_name: "test_name3",
      wa_messages: [
        %WAMsg{
          message: "Test leaf content page 3",
          buttons: [%Btn.Next{title: "Next"}]
        },
        %WAMsg{
          message: "Last message"
        }
      ]
    }

    leaf_page4 = %ContentPage{
      parent: "topic-1",
      slug: "leaf-page-4",
      title: "Leaf Page 4",
      wa_messages: [
        %WAMsg{
          message: "Test leaf content page 4",
          buttons: [%Btn.Next{title: "Next"}]
        },
        %WAMsg{
          message: "Last message"
        }
      ]
    }

    leaf_page5 = %ContentPage{
      parent: "topic-1",
      slug: "leaf-page-5",
      title: "Leaf Page 5",
      whatsapp_template_name: "test_name5",
      wa_messages: [
        %WAMsg{
          message: "Test leaf content page 5",
          buttons: [%Btn.Next{title: "Next"}]
        },
        %WAMsg{
          message: "Last message"
        }
      ]
    }

    leaf_page6 = %ContentPage{
      parent: "topic-1",
      slug: "leaf-page-6",
      title: "Leaf Page 6",
      wa_messages: [
        %WAMsg{
          message: "Test leaf content page 6",
          buttons: [%Btn.Next{title: "Next"}]
        },
        %WAMsg{
          message: "Last message"
        }
      ]
    }

    leaf_page7 = %ContentPage{
      parent: "topic-1",
      slug: "leaf-page-7",
      title: "Leaf Page 7",
      whatsapp_template_name: "test_name7",
      wa_messages: [
        %WAMsg{
          message: "Test leaf content page 7",
          buttons: [%Btn.Next{title: "Next"}]
        },
        %WAMsg{
          message: "Last message"
        }
      ]
    }

    leaf_page8 = %ContentPage{
      parent: "topic-1",
      slug: "leaf-page-8",
      title: "Leaf Page 8",
      wa_messages: [
        %WAMsg{
          message: "Test leaf content page 8",
          buttons: [%Btn.Next{title: "Next"}]
        },
        %WAMsg{
          message: "Last message"
        }
      ]
    }

    ocs1 = %OrderedContentSet{
      id: 1,
      name: "Test Ordered Content Set",
      profile_fields: [%ProfileField{name: "relationship", value: "single"}],
      pages: [
        %OrderedContentSetPage{
          slug: "leaf-page-1",
          time: 1,
          unit: "day",
          before_or_after: "before",
          contact_field: "edd"
        },
        %OrderedContentSetPage{
          slug: "leaf-page-2",
          time: 5,
          unit: "minutes",
          before_or_after: "after",
          contact_field: "edd"
        }
      ]
    }

    ocs2 = %OrderedContentSet{
      id: 2,
      name: "Test Ordered Content Set 2",
      profile_fields: [%ProfileField{name: "age", value: "15 - 18"}],
      pages: [
        %OrderedContentSetPage{
          slug: "leaf-page-3",
          time: 1,
          unit: "day",
          before_or_after: "before",
          contact_field: "edd"
        },
        %OrderedContentSetPage{
          slug: "leaf-page-4",
          time: 5,
          unit: "minutes",
          before_or_after: "after",
          contact_field: "edd"
        }
      ]
    }

    ocs3 = %OrderedContentSet{
      id: 3,
      name: "Test Ordered Content Set3",
      profile_fields: [%ProfileField{name: "relationship", value: "in a relationship"}],
      pages: [
        %OrderedContentSetPage{
          slug: "leaf-page-5",
          time: 1,
          unit: "day",
          before_or_after: "before",
          contact_field: "edd"
        },
        %OrderedContentSetPage{
          slug: "leaf-page-6",
          time: 5,
          unit: "minutes",
          before_or_after: "after",
          contact_field: "edd"
        }
      ]
    }

    ocs4 = %OrderedContentSet{
      id: 4,
      name: "Test Ordered Content Set4",
      profile_fields: [%ProfileField{name: "gender", value: "male"}],
      pages: [
        %OrderedContentSetPage{
          slug: "leaf-page-7",
          time: 1,
          unit: "day",
          before_or_after: "before",
          contact_field: "edd"
        },
        %OrderedContentSetPage{
          slug: "leaf-page-8",
          time: 5,
          unit: "minutes",
          before_or_after: "after",
          contact_field: "edd"
        }
      ]
    }

    assert :ok =
             FakeCMS.add_pages(wh_pid, [
               topic1_index,
               leaf_page,
               leaf_page2,
               leaf_page3,
               leaf_page4,
               leaf_page5,
               leaf_page6,
               leaf_page7,
               leaf_page8,
             ])

    assert :ok =
             FakeCMS.add_ordered_content_sets(wh_pid, [
               ocs1,
               ocs2,
               ocs3,
               ocs4,
             ])

    # Return the adapter.
    FakeCMS.wh_adapter(wh_pid)
  end

  defp fake_cms(step, base_url, auth_token),
    do: WH.set_adapter(step, base_url, setup_fake_cms(auth_token))

  defp setup_contact_fields(context) do
    context
    |> FlowTester.set_contact_properties(%{"gender" => "", "year_of_birth" => "1988", "relationship_status" => ""})
  end

  defp setup_flow() do
    auth_token = "testtoken"

    flow_path("send_next_message")
    |> FlowTester.from_json!()
    |> fake_cms("https://content-repo-api-qa.prk-k8s.prd-p6t.org/", auth_token)
    |> FlowTester.set_global_dict("config", %{"contentrepo_token" => auth_token})
    |> setup_contact_fields()
  end

  describe "push messaging" do
    test "send whatsapp template" do
      fake_time = ~U[2023-02-28 00:00:00Z]
      # 5.5 minutes later
      future_fake_time = DateTime.add(fake_time, 330, :second)
      string_fake_time = DateTime.to_iso8601(fake_time)

      setup_flow()
      |> FlowTester.set_fake_time(future_fake_time)
      |> FlowTester.set_contact_properties(%{"push_messaging_signup" => string_fake_time})
      |> FlowTester.start()
      |> result_matches(%{name: "template_sent", value: "test_name"})
    end

    test "send regular message" do
      fake_time = ~U[2023-02-28 00:00:00Z]
      # 3 minutes later
      future_fake_time = DateTime.add(fake_time, 180, :second)
      string_fake_time = DateTime.to_iso8601(fake_time)

      setup_flow()
      |> FlowTester.set_fake_time(future_fake_time)
      |> FlowTester.set_contact_properties(%{"push_messaging_signup" => string_fake_time})
      |> FlowTester.start()
      |> receive_message(%{
        text: "Leaf Page 2\n\nTest leaf content page 2\n"
      })
      |> result_matches(%{name: "message_sent", value: "3"})
    end

    test "filter by relationship status" do
      fake_time = ~U[2023-02-28 00:00:00Z]
      # 3 minutes later
      future_fake_time = DateTime.add(fake_time, 180, :second)
      string_fake_time = DateTime.to_iso8601(fake_time)

      setup_flow()
      |> FlowTester.set_fake_time(future_fake_time)
      |> FlowTester.set_contact_properties(%{"push_messaging_signup" => string_fake_time, "relationship_status" => "in a relationship"})
      |> FlowTester.start()
      |> receive_message(%{
        text: "Leaf Page 6\n\nTest leaf content page 6\n"
      })
      |> result_matches(%{name: "message_sent", value: "7"})
    end

    test "filter by age range" do
      fake_time = ~U[2023-02-28 00:00:00Z]
      # 3 minutes later
      future_fake_time = DateTime.add(fake_time, 180, :second)
      string_fake_time = DateTime.to_iso8601(fake_time)

      setup_flow()
      |> FlowTester.set_fake_time(future_fake_time)
      |> FlowTester.set_contact_properties(%{"year_of_birth" => "2010", "push_messaging_signup" => string_fake_time})
      |> FlowTester.start()
      |> receive_message(%{
        text: "Leaf Page 2\n\nTest leaf content page 2\n"
      })
      |> result_matches(%{name: "message_sent", value: "3"})
    end

    test "filter by gender" do
      fake_time = ~U[2023-02-28 00:00:00Z]
      # 3 minutes later
      future_fake_time = DateTime.add(fake_time, 180, :second)
      string_fake_time = DateTime.to_iso8601(fake_time)

      setup_flow()
      |> FlowTester.set_fake_time(future_fake_time)
      |> FlowTester.set_contact_properties(%{"gender" => "male", "push_messaging_signup" => string_fake_time})
      |> FlowTester.start()
      |> receive_message(%{
        text: "Leaf Page 8\n\nTest leaf content page 8\n"
      })
      |> result_matches(%{name: "message_sent", value: "9"})
    end
  end
end
