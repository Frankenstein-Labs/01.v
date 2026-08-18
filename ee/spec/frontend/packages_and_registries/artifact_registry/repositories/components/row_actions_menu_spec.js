import { GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RowActionsMenu from 'ee/packages_and_registries/artifact_registry/repositories/components/row_actions_menu.vue';
import { mockRepository } from '../../mock_data';

describe('ArtifactRegistryRepositoryRowActionsMenu', () => {
  let wrapper;

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findEditItem = () => wrapper.findComponent(GlDisclosureDropdownItem);

  const createComponent = ({ repository = mockRepository } = {}) => {
    wrapper = shallowMountExtended(RowActionsMenu, { propsData: { repository } });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders as an icon-only kebab, so the column stays narrow', () => {
    expect(findDropdown().props()).toMatchObject({
      icon: 'ellipsis_v',
      noCaret: true,
      textSrOnly: true,
      placement: 'bottom-end',
    });
  });

  it('names the repository in the toggle, because the menu repeats once per row', () => {
    expect(findDropdown().props('toggleText')).toBe('More actions for my-repository');
  });

  it('routes to the edit view for its own repository', () => {
    expect(findEditItem().props('item')).toEqual({
      text: 'Edit repository',
      to: { name: 'repository_edit', params: { id: 'my-repository' } },
    });
  });
});
