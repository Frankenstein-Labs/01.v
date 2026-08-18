import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RiskScoreTooltip from 'ee/security_dashboard/components/shared/risk_score_tooltip.vue';

describe('RiskScoreTooltip', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(RiskScoreTooltip, {
      stubs: {
        GlSprintf,
      },
    });
  };

  const findFormulaDescription = () => wrapper.find('p');
  const findExplanationItems = () => wrapper.findAll('ol li');

  beforeEach(createComponent);

  it('renders the risk score formula description', () => {
    expect(findFormulaDescription().text()).toMatchInterpolatedText(
      '(Sum of open vulnerability scores%{supStart}*%{supEnd} + Age penalty%{supStart}†%{supEnd}) * Diminishing factor%{supStart}‡%{supEnd} * Diversity factor%{supStart}§%{supEnd}',
    );
  });

  it('renders the open vulnerability scores explanation', () => {
    expect(findExplanationItems().at(0).text()).toMatchInterpolatedText(
      '%{supStart}*%{supEnd}Base score (associated with severity level) + EPSS modifier + KEV modifier',
    );
  });

  it('renders the age penalty explanation', () => {
    expect(findExplanationItems().at(1).text()).toMatchInterpolatedText(
      '%{supStart}†%{supEnd}Sum of vulnerability ages in months * 0.005',
    );
  });

  it('renders the diminishing factor explanation', () => {
    expect(findExplanationItems().at(2).text()).toMatchInterpolatedText(
      '%{supStart}‡%{supEnd}Diminishing factor = 1.0 / √(vulnerability count)',
    );
  });

  it('renders the diversity factor explanation', () => {
    expect(findExplanationItems().at(3).text()).toMatchInterpolatedText(
      '%{supStart}§%{supEnd}Diversity factor = 0.4',
    );
  });
});
