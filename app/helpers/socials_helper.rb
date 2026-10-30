module SocialsHelper
  def socials_invitations_received
    return @socials_invitations_received if defined?(@socials_invitations_received)

    @socials_invitations_received = @invitations ? @invitations.received.size : Game::InvitationsOf.call(current_player).received.size
  end
end
