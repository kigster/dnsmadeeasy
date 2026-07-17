# frozen_string_literal: true

module DnsMadeEasy
  module CLI
    # Raised after an error has already been rendered to the user;
    # the Launcher exits non-zero without printing it again.
    class ReportedError < StandardError
    end
  end
end
