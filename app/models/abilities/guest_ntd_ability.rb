module Abilities
  class GuestNtdAbility
    include CanCan::Ability

    def initialize(user)

      cannot :manage, NtdForm

    end
  end
end