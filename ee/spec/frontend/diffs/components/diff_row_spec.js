import { shallowMount } from '@vue/test-utils';
import waitForPromises from 'helpers/wait_for_promises';
import DiffRow from '~/diffs/components/diff_row.vue';

describe('EE DiffRow', () => {
  let wrapper;

  const findIcon = () => wrapper.find('[data-testid="inlineFindingsIcon"]');

  const defaultProps = {
    fileHash: 'abc',
    filePath: 'abc',
    line: {},
    index: 0,
    isHighlighted: false,
    fileLineCoverage: () => ({}),
    userCanReply: true,
  };

  const createComponent = ({ props }) => {
    wrapper = shallowMount(DiffRow, {
      propsData: { ...defaultProps, ...props },
    });
  };

  describe('with a new code quality violation', () => {
    beforeEach(() => {
      createComponent({
        props: { line: { right: { codequality: [{ severity: 'critical' }] } } },
      });
    });

    it('shows code quality gutter icon', async () => {
      // The gutter icon dropdown is an async component.
      await waitForPromises();

      expect(findIcon().exists()).toBe(true);
    });
  });

  describe('with no new code quality violations', () => {
    beforeEach(() => {
      createComponent({
        props: { line: { right: { codequality: [] } } },
      });
    });

    it('does not show code quality gutter icon', () => {
      expect(findIcon().exists()).toBe(false);
    });
  });
});
