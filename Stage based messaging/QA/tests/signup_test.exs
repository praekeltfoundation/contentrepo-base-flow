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

    assert :ok =
             FakeCMS.add_pages(wh_pid, [
               topic1_index,
               leaf_page,
             ])

    assert :ok = FakeCMS.add_images(wh_pid, [image])

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

    flow_path("signup")
    |> FlowTester.from_json!()
    |> fake_cms("https://content-repo-api-qa.prk-k8s.prd-p6t.org/", auth_token)
    |> FlowTester.set_global_dict("config", %{"contentrepo_token" => auth_token})
    |> setup_contact_fields()
  end

  describe "stage based messaging signup" do
    test "show menu of index pages when starting the flow" do
      setup_flow()
      |> FlowTester.start()
      |> receive_message(%{
        text: "*How can I help you today?*\n-----\nSelect the topic that you're interested in.\n",
        list: {"Select topic", [{"Topic 1", "Topic 1"}, {"Media Topic", "Media Topic"}]}
      })
    end
  end
end
