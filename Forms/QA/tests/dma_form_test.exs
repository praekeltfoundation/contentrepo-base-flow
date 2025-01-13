defmodule DMAFormTest do
  use FlowTester.Case
  use FakeCMS

  alias FlowTester.WebhookHandler, as: WH
  alias FlowTester.Result
  alias FlowTester.FlowStep

  defp flow_path(flow_name), do: Path.join([__DIR__, "..", "flows_json", flow_name <> ".json"])

  def setup_fake_cms(auth_token) do
    # Start the handler.
    wh_pid = start_link_supervised!({FakeCMS, %FakeCMS.Config{auth_token: auth_token}})

    FakeCMS.add_image(wh_pid, %Image{
      id: 1,
      download_url: "https://example.com/image.jpg",
      title: "Test image"
    })

    FakeCMS.add_page(wh_pid, %Index{slug: "home", title: "Home"})

    FakeCMS.add_page(wh_pid, %ContentPage{
      parent: "home",
      slug: "mnch_onboarding_dma_results_high",
      title: "DMA_results_high",
      wa_messages: [
        %WAMsg{
          message:
            "*Thank you for completing this*\n\nYou seem comfortable and confident making decisions about your health.\n\nKeep on doing what you’re doing! 🤩"
        }
      ]
    })

    FakeCMS.add_page(wh_pid, %ContentPage{
      parent: "home",
      slug: "skip-result-page",
      title: "Skip Result Page",
      wa_messages: [
        %WAMsg{
          message: "You are seeing this message because you skipped an answer.",
          image: 1
        }
      ]
    })

    FakeCMS.add_form(wh_pid, %Form{
      id: 1,
      title: "DMA_Form_01",
      slug: "mnch_onboarding_dma_form",
      generic_error: "Please choose an option that matches your answer",
      version: "v1.0",
      locale: "en",
      tags: ["dma_form"],
      high_inflection: 5.0,
      high_result_page: "mnch_onboarding_dma_results_high",
      medium_inflection: 3.0,
      skip_threshold: 1.0,
      skip_high_result_page: "skip-result-page",
      questions: [
        %Forms.CategoricalQuestion{
          question:
            "Thanks, {{name}}\n\nNow please share your view on these statements so that you can get the best support from [MyHealth] for your needs.\n\nTo skip any question, reply: Skip\n\nHere’s the first statement:\n\n👤 *I am confident that I can do things to avoid health issues or reduce my symptoms.*",
          semantic_id: "dma-do-things",
          answers: [
            %Forms.Answer{
              score: 2.0,
              answer: "Strongly disagree",
              semantic_id: "dma_form01_strongly_disagree"
            },
            %Forms.Answer{
              score: 1.0,
              answer: "Disagree",
              semantic_id: "dma_form01_disagree"
            },
            %Forms.Answer{
              score: 0.0,
              answer: "Neutral",
              semantic_id: "dma_form01_neutral"
            },
            %Forms.Answer{
              score: 1.0,
              answer: "Agree",
              semantic_id: "dma_form01_agree"
            },
            %Forms.Answer{
              score: 2.0,
              answer: "Strongly Agree",
              semantic_id: "dma_form01_strongly_agree",
              response: "You chose strongly agree!"
            }
          ]
        }
      ]
    })

    # Return the adapter.
    FakeCMS.wh_adapter(wh_pid)
  end

  defp fake_cms(step, base_url, auth_token),
    do: WH.set_adapter(step, base_url, setup_fake_cms(auth_token))

  defp setup_flow() do
    auth_token = "testtoken"

    flow_path("DMA Form")
    |> FlowTester.from_json!()
    |> fake_cms("https://content-repo-api-qa.prk-k8s.prd-p6t.org/", auth_token)
    |> FlowTester.set_global_dict("config", %{"contentrepo_token" => auth_token})
    |> FlowTester.set_contact_properties(%{"name" => "Lethabo"})
  end

  describe "dma form" do
    test "show the first question when started" do
      setup_flow()
      |> FlowTester.set_local_params("config", %{"assessment_tag" => "dma_form"})
      |> FlowTester.start()
      |> receive_message(%{
        text: "Thanks, Lethabo\n\nNow please share your view on these statements" <> _,
        list:
          {"Select option",
           [
             {"Strongly disagree", "Strongly disagree"},
             {"Disagree", "Disagree"},
             {"Neutral", "Neutral"},
             {"Agree", "Agree"},
             {"Strongly Agree", "Strongly Agree"}
           ]}
      })
      |> results_match([
        %Result{name: "version", value: "v1.0"},
        %Result{name: "started", value: "dma_form"},
        %Result{name: "locale", value: "en"}
      ])
    end

    test "store the results when a question is answered" do
      setup_flow()
      |> FlowTester.start()
      |> FlowStep.clear_messages()
      |> FlowStep.clear_results()
      |> FlowTester.send("Agree")
      |> receive_message(%{text: "*Thank you for completing this*" <> _})
      |> results_match([
        %Result{name: "question_num", value: 0},
        %Result{name: "question_id", value: "dma_form01_agree"} | _
      ])
    end

    test "store the results when a question is skipped" do
      setup_flow()
      |> FlowTester.start()
      |> FlowStep.clear_messages()
      |> FlowStep.clear_results()
      |> FlowTester.send("skip")
      |> receive_message(%{text: "You are seeing this message because you skipped an answer."})
      |> results_match([
        %Result{name: "question_num", value: 0},
        %Result{name: "question_id", value: "skip"} | _
      ])
    end

    test "store the results when a form is completed" do
      setup_flow()
      |> FlowTester.start()
      |> FlowStep.clear_messages()
      |> FlowStep.clear_results()
      |> FlowTester.send("Agree")
      |> receive_message(%{text: "*Thank you for completing this*" <> _})
      |> results_match([
        _,
        _,
        %Result{name: "end", value: "mnch_onboarding_dma_form"},
        %Result{name: "risk", value: "high"},
        %Result{name: "score", value: 1.0},
        %Result{name: "max_score", value: 2.0}
      ])
    end

    test "shows response if answer has response" do
      setup_flow()
      |> FlowTester.set_local_params("config", %{"response_button_text" => "Next question"})
      |> FlowTester.start()
      |> FlowStep.clear_messages()
      |> FlowStep.clear_results()
      |> FlowTester.send("Strongly Agree")
      |> receive_message(%{
        text: "You chose strongly agree!",
        buttons: [{"@config.items.response_button_text", "Next question"}]
      })
      |> FlowTester.send("Next question")
      |> receive_message(%{
        text: "*Thank you for completing this*" <> _
      })
    end

    test "supports images in result page" do
      setup_flow()
      |> FlowTester.start()
      |> FlowStep.clear_messages()
      |> FlowStep.clear_results()
      |> FlowTester.send("skip")
      |> receive_message(%{
        text: "You are seeing this message because you skipped an answer.",
        image: "https://example.com/image.jpg"
      })
    end
  end
end
