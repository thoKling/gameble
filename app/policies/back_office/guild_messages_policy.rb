module BackOffice
  class GuildMessagesPolicy < ApplicationPolicy
    def index? = moderator?
    def hide? = moderator?
    def dismiss? = moderator?
  end
end
