module OpenAIClient
  module_function

  def configured?
    ENV["OPENAI_API_KEY"].to_s.strip.present?
  end

  def build
    return nil unless configured?
    OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"), request_timeout: 20)
  end
end
