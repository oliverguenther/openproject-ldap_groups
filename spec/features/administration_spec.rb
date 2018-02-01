require_relative '../spec_helper'

describe 'LDAP group sync administration spec', type: :feature, js: true do
  let(:admin) { FactoryGirl.create :admin }

  before do
    login_as admin
    visit ldap_groups_synchronized_groups_path
  end

  context 'without EE', with_group_ee: false do
    it 'shows upsale' do
      expect(page).to have_selector('.upsale-notification')
    end
  end

  context 'with EE', with_group_ee: true do
    let!(:group) { FactoryGirl.create :group, lastname: 'foo' }
    let!(:auth_source) { FactoryGirl.create :ldap_auth_source, name: 'ldap' }

    it 'allows synced group administration flow' do
      expect(page).to have_no_selector('.upsale-notification')

      # Create group
      find('.button.-alt-highlight', text: I18n.t('ldap_groups.synchronized_groups.singular')).click

      select 'ldap', from: 'synchronized_group_auth_source_id'
      select 'foo', from: 'synchronized_group_group_id'
      fill_in 'synchronized_group_entry', with: 'attr'

      click_on 'Create'
      expect(page).to have_selector('.flash.notice', text: I18n.t(:notice_successful_create))
      expect(page).to have_selector('td.entry', text: 'attr')
      expect(page).to have_selector('td.auth_source', text: 'ldap')
      expect(page).to have_selector('td.group', text: 'foo')
      expect(page).to have_selector('td.users', text: '0')

      # Show entry
      find('td.entry a').click
      expect(page).to have_selector '.generic-table--empty-row'

      # Check created group
      sync = ::LdapGroups::SynchronizedGroup.last
      expect(sync.group_id).to eq(group.id)
      expect(sync.auth_source_id).to eq(auth_source.id)
      expect(sync.entry).to eq 'attr'

      # Assume we have a membership
      sync.users.create user_id: admin.id
      visit ldap_groups_synchronized_group_path(sync)
      expect(page).to have_selector 'td.user', text: admin.name

      memberships = sync.users.pluck(:id)

      visit ldap_groups_synchronized_groups_path
      find('.buttons a', text: 'Delete').click
      find('.danger-zone--verification input').set 'attr'
      click_on 'Delete'

      expect(page).to have_selector('.flash.notice', text: I18n.t(:notice_successful_delete))
      expect(page).to have_selector '.generic-table--empty-row'

      expect(::LdapGroups::Membership.where(id: memberships)).to be_empty
    end
  end
end