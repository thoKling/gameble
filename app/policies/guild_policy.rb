class GuildPolicy < ApplicationPolicy
  def show? = player?
  def create? = player?
  def join? = player?
  def leave? = player?
  def remove? = player?
end
