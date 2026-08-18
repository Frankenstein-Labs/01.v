import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AuditorAccessSummary from 'ee/admin/users/components/user_type/auditor_access_summary.vue';
import AccessSummary from '~/admin/users/components/user_type/access_summary.vue';
import { RENDER_ALL_SLOTS_TEMPLATE, stubComponent } from 'helpers/stub_component';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';

describe('AuditorAccessSummary component', () => {
  let wrapper;

  const createWrapper = (slotContent) => {
    wrapper = shallowMountExtended(AuditorAccessSummary, {
      scopedSlots: slotContent ? { default: slotContent } : null,
      stubs: {
        GlSprintf,
        AccessSummary: stubComponent(AccessSummary, { template: RENDER_ALL_SLOTS_TEMPLATE }),
      },
    });
  };

  const findAdminListItem = () => wrapper.findByTestId('slot-admin-list').find('li');
  const findAllGroupListItems = () => wrapper.findByTestId('slot-group-list').findAll('li');
  const findSettingsListItem = () => wrapper.findByTestId('slot-settings-list').find('li');

  describe('access summary', () => {
    beforeEach(() => createWrapper());

    it('shows access summary', () => {
      expect(wrapper.findComponent(AccessSummary).exists()).toBe(true);
    });

    it('shows admin list item', () => {
      expect(findAdminListItem().text()).toBe('No access.');
    });

    describe('group section', () => {
      it('shows first list item', () => {
        expect(findAllGroupListItems().at(0).text()).toBe(
          'Read access to all groups and projects.',
        );
      });

      describe('second list item', () => {
        it('shows list item', () => {
          expect(findAllGroupListItems().at(1).text()).toMatchInterpolatedText(
            'May be directly added to groups and projects. Learn more about auditor role.',
          );
        });

        it('shows link', () => {
          const link = findAllGroupListItems().at(1).findComponent(HelpPageLink);

          expect(link.text()).toBe('Learn more about auditor role.');
          expect(link.props('href')).toBe('administration/auditor_users');
          expect(link.attributes('target')).toBe('_blank');
        });
      });
    });

    it('shows settings list item', () => {
      expect(findSettingsListItem().text()).toBe(
        'Requires at least Maintainer role in specific groups and projects.',
      );
    });
  });

  describe('when admin slot content is provided', () => {
    beforeEach(() => createWrapper('<div>admin slot content</div>'));

    it('shows slot content', () => {
      expect(wrapper.findByTestId('slot-admin-content').text()).toBe('admin slot content');
    });

    it('does not show admin list item', () => {
      expect(wrapper.findByTestId('slot-admin-list').exists()).toBe(false);
    });
  });
});
