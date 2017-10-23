module Abilities
  class AuthorizedNtdAbility
    include CanCan::Ability

    def initialize(user, organization_ids=[])

      if organization_ids.empty?
        organization_ids = user.organization_ids
      end

      can :manage, NtdForm do |n|
        organization_ids.include? n.organization_id
      end

    end
  end
end