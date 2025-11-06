class TestChannel < ApplicationCable::Channel
  def subscribed
    stream_from "test_stream"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
