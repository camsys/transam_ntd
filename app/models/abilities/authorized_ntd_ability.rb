module Abilities
  class AuthorizedNtdAbility
    include CanCan::Ability

    def initialize(user)

      can :manage, NtdForm do |n|
        user.organization_ids.include? n.organization_id
      end

    end
  end
end