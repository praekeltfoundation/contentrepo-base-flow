defmodule SignupTest do
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

    ocs1 = %OrderedContentSet{
      id: 1,
      name: "Test Ordered Content Set",
      profile_fields: [%ProfileField{name: "relationship", value: "single"}],
      pages: [
        %OrderedContentSetPage{
          contentpage_id: 2,
          time: 1,
          unit: "day",
          before_or_after: "before",
          contact_field: "edd"
        }
      ]
    }

    ocs2 = %OrderedContentSet{
      id: 2,
      name: "Test Ordered Content Set 2",
      profile_fields: [%ProfileField{name: "relationship", value: "it's complicated"}],
      pages: [
        %OrderedContentSetPage{
          contentpage_id: 3,
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
               leaf_page2
             ])

    assert :ok =
             FakeCMS.add_ordered_content_sets(wh_pid, [
               ocs1,
               ocs2
             ])

    # Return the adapter.
    FakeCMS.wh_adapter(wh_pid)
  end

  defp fake_cms(step, base_url, auth_token),
    do: WH.set_adapter(step, base_url, setup_fake_cms(auth_token))

  defp setup_contact_fields(context) do
    context |> FlowTester.set_contact_properties(%{"gender" => "", "age" => "", "relationship" => ""})
  end

  defp setup_flow() do
    auth_token = "testtoken"

    flow_path("signup")
    |> FlowTester.from_json!()
    |> fake_cms("https://content-repo-api-qa.prk-k8s.prd-p6t.org/", auth_token)
    |> FlowTester.set_global_dict("config", %{"contentrepo_token" => auth_token})
    |> setup_contact_fields()
  end

  describe "push messaging signup" do
    test "AskSignup" do
      setup_flow()
      |> FlowTester.start()
      |> receive_message(%{
        text:
          "Hi!\n\nWould you like to sign up to our testing messaging set?\n\nYou will receive 5 messages, one every 5 minutes.\n",
        buttons: [{"Yes, please", "Yes, please"}, {"No, thank you", "No, thank you"}]
      })
    end

    test "AskSignup -> Exit" do
      setup_flow()
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("No, thank you")
      |> receive_message(%{
        text: "Thank you! You will not be sent any messages."
      })
      |> result_matches(%{name: "push_messaging_signup", value: "no"})
      |> flow_finished()
    end

    test "AskSignup -> CompleteSignup" do
      fake_time = ~U[2023-02-28 00:00:00Z]
      string_fake_time = DateTime.to_iso8601(fake_time)

      setup_flow()
      |> FlowTester.set_fake_time(fake_time)
      |> FlowTester.start()
      |> receive_message(%{})
      |> FlowTester.send("Yes, please")
      |> receive_message(%{
        text: "Thank you for signing up! You will receive your first message shortly"
      })
      |> contact_matches(%{"push_messaging_signup" => ^string_fake_time})
      |> result_matches(%{name: "push_messaging_signup", value: "contentset_id"})
      |> flow_finished()
    end
  end
end
