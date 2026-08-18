import { GlLink } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import IterationPresenter from 'ee/glql/components/presenters/iteration.vue';
import { MOCK_ITERATION, MOCK_ITERATION_MANUAL } from '../../mock_data';

describe('IterationPresenter', () => {
  let wrapper;

  const createWrapper = ({ data }) => {
    wrapper = mountExtended(IterationPresenter, {
      propsData: { data },
    });
  };

  const findLink = () => wrapper.findComponent(GlLink);

  it.each`
    iterationType                            | iteration                | expectedText1                      | expectedText2                            | expectedLinkHref
    ${'an iteration with automatic cadence'} | ${MOCK_ITERATION}        | ${'testt'}                         | ${'Oct 1 – 14'}                          | ${'https://gitlab.com/groups/gitlab-org/-/iterations/1'}
    ${'an iteration with manual cadence'}    | ${MOCK_ITERATION_MANUAL} | ${'AAAA Manual iteration cadence'} | ${'Nov 1 – 30, 2024 • Manual iteration'} | ${'https://gitlab.com/groups/gitlab-org/-/iterations/3508'}
  `(
    'correctly renders $iterationType',
    ({ iteration, expectedText1, expectedText2, expectedLinkHref }) => {
      createWrapper({ data: iteration });

      expect(wrapper.text()).toContain(expectedText1);
      expect(wrapper.text()).toContain(expectedText2);

      expect(findLink().attributes('href')).toEqual(expectedLinkHref);
    },
  );
});
