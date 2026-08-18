import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import SolutionCard from 'ee/vue_shared/security_reports/components/solution_card.vue';

jest.mock('~/behaviors/markdown/render_gfm');

describe('Solution Card', () => {
  const solutionHtml = 'Upgrade to XYZ';
  const solutionText = 'Plain text solution';

  let wrapper;

  const findSolutionHtml = () => wrapper.findByTestId('solution-html');
  const findSolutionText = () => wrapper.findByTestId('solution-text');
  const findCreateMrMessage = () => wrapper.findByTestId('create-mr-message');
  const findSolutionTitle = () => wrapper.find('h3');

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(SolutionCard, {
      propsData: { canDownloadPatch: false, ...propsData },
    });
  };

  describe('with solutionHtml', () => {
    beforeEach(() => createComponent({ propsData: { solutionHtml } }));

    it('renders the solution title', () => {
      expect(findSolutionTitle().text()).toBe('Remediation Guidance');
    });

    it('renders the solution html', () => {
      expect(findSolutionHtml().text()).toBe(solutionHtml);
    });

    it('does not render the plain text paragraph', () => {
      expect(findSolutionText().exists()).toBe(false);
    });

    it('renders gfm', () => {
      expect(renderGFM).toHaveBeenCalledWith(findSolutionHtml().element);
    });
  });

  describe('with solutionText (no solutionHtml)', () => {
    beforeEach(() => createComponent({ propsData: { solutionText } }));

    it('renders the solution title', () => {
      expect(findSolutionTitle().text()).toBe('Remediation Guidance');
    });

    it('renders the plain text solution', () => {
      expect(findSolutionText().text()).toBe(solutionText);
    });

    it('does not render the html paragraph', () => {
      expect(findSolutionHtml().exists()).toBe(false);
    });

    it('calls renderGFM with undefined (no markdownContent ref)', () => {
      expect(renderGFM).toHaveBeenCalledWith(undefined);
    });
  });

  describe('canDownloadPatch prop', () => {
    it('shows create merge request message if patch can be downloaded', () => {
      createComponent({ propsData: { solutionHtml, canDownloadPatch: true } });

      expect(findCreateMrMessage().text()).toBe(SolutionCard.i18n.createMergeRequestMsg);
    });

    it(`hides create merge request message if patch can't be downloaded`, () => {
      createComponent({ propsData: { solutionHtml, canDownloadPatch: false } });

      expect(findCreateMrMessage().exists()).toBe(false);
    });
  });
});
