module Abilities
  class ManagerNtdAbility
    include CanCan::Ability

    def initialize(user)

      can :manage, NtdForm


    end
  end
end