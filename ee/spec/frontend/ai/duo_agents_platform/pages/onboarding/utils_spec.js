import {
  resolveProjectState,
  resolveAudience,
  isSectionVisible,
} from 'ee/ai/duo_agents_platform/pages/onboarding/utils';
import {
  PROJECT_STATE_READY,
  PROJECT_STATE_ENVIRONMENT_PROBLEM,
  PROJECT_STATE_NOT_ENABLED,
  AUDIENCE_MAINTAINER,
  AUDIENCE_DEVELOPER,
  SECTION_CUSTOMIZE_AGENTS,
} from 'ee/ai/duo_agents_platform/pages/onboarding/constants';

describe('duo agents platform onboarding utils', () => {
  describe('resolveProjectState', () => {
    it.each`
      dapAvailable | environmentHealthy | expected
      ${false}     | ${true}            | ${PROJECT_STATE_NOT_ENABLED}
      ${false}     | ${false}           | ${PROJECT_STATE_NOT_ENABLED}
      ${true}      | ${false}           | ${PROJECT_STATE_ENVIRONMENT_PROBLEM}
      ${true}      | ${true}            | ${PROJECT_STATE_READY}
    `(
      'returns $expected when dapAvailable=$dapAvailable, environmentHealthy=$environmentHealthy',
      ({ dapAvailable, environmentHealthy, expected }) => {
        expect(resolveProjectState({ dapAvailable, environmentHealthy })).toBe(expected);
      },
    );
  });

  describe('resolveAudience', () => {
    it('returns maintainer when the user can administer the project, developer otherwise', () => {
      expect(resolveAudience(true)).toBe(AUDIENCE_MAINTAINER);
      expect(resolveAudience(false)).toBe(AUDIENCE_DEVELOPER);
    });
  });

  describe('isSectionVisible', () => {
    it('shows Customize agents to a maintainer in a configured state', () => {
      expect(
        isSectionVisible(SECTION_CUSTOMIZE_AGENTS, {
          state: PROJECT_STATE_READY,
          audience: AUDIENCE_MAINTAINER,
        }),
      ).toBe(true);
    });

    it.each`
      state                        | audience               | reason
      ${PROJECT_STATE_READY}       | ${AUDIENCE_DEVELOPER}  | ${'developer'}
      ${PROJECT_STATE_NOT_ENABLED} | ${AUDIENCE_MAINTAINER} | ${'not-enabled state'}
    `('hides Customize agents for a $reason', ({ state, audience }) => {
      expect(isSectionVisible(SECTION_CUSTOMIZE_AGENTS, { state, audience })).toBe(false);
    });

    it('returns false for an unknown section', () => {
      expect(
        isSectionVisible('unknown', { state: PROJECT_STATE_READY, audience: AUDIENCE_MAINTAINER }),
      ).toBe(false);
    });
  });
});
