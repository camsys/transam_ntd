module Abilities
  class ManagerNtdAbility
    include CanCan::Ability

    def initialize(user)

      can :manage, NtdForm
      can :manage, AssetFleet


    end
  end
end