import { GlPopover, GlSprintf, GlLink, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BreakingChangesIcon from 'ee/security_orchestration/components/policies/breaking_changes_icon.vue';

describe('BreakingChangesIcon', () => {
  let wrapper;

  const violationList = [1, 2].map((id) => ({
    content: `content %{linkStart}${id}%{linkEnd}`,
    link: `link ${id}`,
  }));

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(BreakingChangesIcon, {
      propsData: {
        id: '1',
        violationList,
        ...propsData,
      },
      stubs: {
        GlPopover,
        GlSprintf,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findLink = () => wrapper.findComponent(GlLink);
  const findViolationItem = (index) => wrapper.findByTestId(`violation-item-${index}`);

  it('renders warning icon and popover by default', () => {
    createComponent();

    expect(findIcon().props('name')).toBe('error');
    expect(findIcon().props('variant')).toBe('danger');

    expect(findViolationItem(0).text()).toBe('content 1');
    expect(findViolationItem(1).text()).toBe('content 2');

    expect(findViolationItem(0).findComponent(GlLink).text()).toBe('1');
    expect(findViolationItem(0).findComponent(GlLink).attributes('href')).toBe('link 1');

    expect(findViolationItem(1).text()).toBe('content 2');
    expect(findViolationItem(1).findComponent(GlLink).text()).toBe('2');
    expect(findViolationItem(1).findComponent(GlLink).attributes('href')).toBe('link 2');
  });

  it('renders warning icon and popover with link for single list', () => {
    createComponent({
      propsData: { violationList: [violationList[0]] },
    });

    expect(findPopover().text()).toBe('content 1');
    expect(findLink().attributes('href')).toBe('link 1');
  });
});
