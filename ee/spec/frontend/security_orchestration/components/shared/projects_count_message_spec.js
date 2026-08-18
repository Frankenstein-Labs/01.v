import { GlSprintf, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectsCountMessage from 'ee/security_orchestration/components/shared/projects_count_message.vue';

describe('ProjectsCountMessage', () => {
  let wrapper;

  const defaultProps = {
    count: 5,
    totalCount: 10,
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(ProjectsCountMessage, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findMessage = () => wrapper.findByTestId('message');
  const findIcon = () => wrapper.findComponent(GlIcon);

  describe('default rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the component', () => {
      expect(findMessage().text()).toContain('5 of 10');
      expect(findIcon().exists()).toBe(false);
    });
  });

  describe('with different project counts', () => {
    it.each`
      count | totalCount | outcome
      ${0}  | ${10}      | ${'0 of 10'}
      ${1}  | ${10}      | ${'1 of 10'}
      ${5}  | ${10}      | ${'5 of 10'}
      ${10} | ${10}      | ${'10 of 10'}
    `('displays correct message for $description', ({ count, totalCount, outcome }) => {
      createWrapper({ count, totalCount });

      expect(findMessage().text()).toContain(outcome);
    });
  });

  describe('additional elements', () => {
    it('renders info icon', () => {
      createWrapper({
        showInfoIcon: true,
      });

      expect(findIcon().props('name')).toBe('information-o');
      expect(findIcon().props('variant')).toBe('info');
      expect(findIcon().attributes('title')).toBe('Scroll to the bottom to load more items');
    });
  });
});
