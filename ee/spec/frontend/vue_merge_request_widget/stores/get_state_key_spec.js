import getStateKey from 'ee/vue_merge_request_widget/stores/get_state_key';
import {
  DETAILED_MERGE_STATUS,
  MWCP_MERGE_STRATEGY,
  MTWCP_MERGE_STRATEGY,
  MT_MERGE_STRATEGY,
} from '~/vue_merge_request_widget/constants';

describe('EE getStateKey', () => {
  const createContext = (detailedMergeStatus, preferredAutoMergeStrategy, autoMergeEnabled) => ({
    canMerge: true,
    commitsCount: 2,
    detailedMergeStatus,
    preferredAutoMergeStrategy,
    autoMergeEnabled,
  });

  beforeEach(() => {
    window.gon = { features: {} };
  });

  afterEach(() => {
    delete window.gon;
  });

  describe('when auto merge is not enabled', () => {
    describe('with merge train strategy', () => {
      it.each`
        detailedMergeStatus                   | expectedState
        ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${'readyToMerge'}
        ${DETAILED_MERGE_STATUS.NOT_APPROVED} | ${'readyToMerge'}
      `(
        'returns $expectedState when status is $detailedMergeStatus',
        ({ detailedMergeStatus, expectedState }) => {
          const context = createContext(detailedMergeStatus, MT_MERGE_STRATEGY, false);
          const bound = getStateKey.bind(context);

          expect(bound()).toBe(expectedState);
        },
      );

      it('returns readyToMerge when feature flag is undefined', () => {
        // window.gon.features.allowMergeTrainRetryMerge is undefined
        const context = createContext(DETAILED_MERGE_STATUS.MERGEABLE, MT_MERGE_STRATEGY, false);
        const bound = getStateKey.bind(context);

        expect(bound()).toBe('readyToMerge');
      });

      it('returns readyToMerge when gon is undefined', () => {
        delete window.gon;
        const context = createContext(DETAILED_MERGE_STATUS.MERGEABLE, MT_MERGE_STRATEGY, false);
        const bound = getStateKey.bind(context);

        expect(bound()).toBe('readyToMerge');
      });
    });

    describe('with other auto merge strategies', () => {
      it.each`
        strategy                | detailedMergeStatus                   | expectedState
        ${MWCP_MERGE_STRATEGY}  | ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${'readyToMerge'}
        ${MWCP_MERGE_STRATEGY}  | ${DETAILED_MERGE_STATUS.NOT_APPROVED} | ${'readyToMerge'}
        ${MTWCP_MERGE_STRATEGY} | ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${'readyToMerge'}
        ${MTWCP_MERGE_STRATEGY} | ${DETAILED_MERGE_STATUS.NOT_APPROVED} | ${'readyToMerge'}
      `(
        'returns $expectedState for $strategy regardless of feature flag state',
        ({ strategy, detailedMergeStatus, expectedState }) => {
          const context = createContext(detailedMergeStatus, strategy, false);
          const bound = getStateKey.bind(context);

          expect(bound()).toBe(expectedState);
        },
      );
    });
  });

  describe('when auto merge is enabled', () => {
    it.each`
      strategy               | detailedMergeStatus                   | expectedState
      ${MT_MERGE_STRATEGY}   | ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${'readyToMerge'}
      ${MT_MERGE_STRATEGY}   | ${DETAILED_MERGE_STATUS.NOT_APPROVED} | ${null}
      ${MWCP_MERGE_STRATEGY} | ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${'readyToMerge'}
    `(
      'returns $expectedState for $strategy when auto merge is enabled',
      ({ strategy, detailedMergeStatus, expectedState }) => {
        const context = createContext(detailedMergeStatus, strategy, true);
        const bound = getStateKey.bind(context);

        expect(bound()).toBe(expectedState);
      },
    );
  });
});
