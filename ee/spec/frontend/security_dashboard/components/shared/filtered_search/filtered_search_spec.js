import { nextTick, markRaw } from 'vue';
import { GlFilteredSearch } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import FilteredSearch from 'ee/security_dashboard/components/shared/filtered_search/filtered_search.vue';
import { ALL_ID } from 'ee/security_dashboard/components/shared/filtered_search/constants';
import {
  OPERATORS_OR,
  OPERATORS_OR_NOT,
} from '~/vue_shared/components/filtered_search_bar/constants';

const TEST_TOKEN_A_DEFINITION = {
  type: 'tokenA',
  title: 'Token A',
  multiSelect: true,
  unique: true,
  token: markRaw(() => {}),
  operators: OPERATORS_OR,
};

const TEST_TOKEN_B_DEFINITION = {
  ...TEST_TOKEN_A_DEFINITION,
  type: 'tokenB',
  title: 'Token B',
};

const TEST_TOKEN_WITH_DEFAULTS = {
  type: 'tokenWithDefaults',
  title: 'Token With Defaults',
  multiSelect: true,
  unique: true,
  token: markRaw({
    defaultValues: () => ['default1', 'default2'],
  }),
  operators: OPERATORS_OR,
};

const TEST_TOKEN_WITH_TRANSFORMS = {
  type: 'tokenWithTransforms',
  title: 'Token With Transforms',
  multiSelect: true,
  unique: true,
  token: markRaw({
    transformFilters: (data, { filters, operator, dashboardType }) => ({
      ...filters,
      transformedKey: data.map((v) => `${operator === '!=' ? 'not_' : ''}transformed_${v}`),
      ...(dashboardType ? { dashboardType } : {}),
    }),
    transformQueryParams: (data) => data.map((v) => `param_${v}`).join('|'),
    parseQueryParams: (values) => values.map((v) => v.replace('param_', '')),
  }),
  operators: OPERATORS_OR_NOT,
};

describe('Security Dashboard Filtered Search', () => {
  let wrapper;

  const createWrapper = ({ provide = {}, ...props } = {}) => {
    wrapper = shallowMountExtended(FilteredSearch, {
      propsData: {
        tokens: [TEST_TOKEN_A_DEFINITION, TEST_TOKEN_B_DEFINITION],
        ...props,
      },
      provide: {
        defaultBranchContext: null,
        dashboardType: '',
        ...provide,
      },
    });
  };

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);

  // When using this function you need to provide all token values each time.
  // Because it sets the value with `input` event, it does not take into account the previous
  // `value` the filtered search had.
  // Each arg is [type, data] or [type, data, operator].
  const updateValueAndEmit = async (eventName, ...args) => {
    const component = findFilteredSearch().vm;

    component.$emit(
      'input',
      args.map(([type, tokenValue, operator = '||']) => {
        return { type, value: { data: tokenValue, operator } };
      }),
    );

    component.$emit(eventName);

    // the component uses two nextTicks to wait for updated value in Vue 3 compat mode
    await nextTick();
    await nextTick();
  };

  const getLastEmittedUrlParams = () => {
    return wrapper.emitted('url-params-changed').at(-1)[0];
  };

  const getLastEmittedFilters = () => {
    return wrapper.emitted('filters-changed').at(-1)[0];
  };

  afterEach(() => {
    setWindowLocation('');
  });

  it('renders GlFilteredSearch with correct props', () => {
    createWrapper();

    const filteredSearch = findFilteredSearch();

    expect(filteredSearch.props()).toMatchObject({
      placeholder: 'Filter results...',
      availableTokens: [TEST_TOKEN_A_DEFINITION, TEST_TOKEN_B_DEFINITION],
      value: [],
    });
  });

  describe('filters-changed event', () => {
    beforeEach(createWrapper);

    it('emits filters-changed when token is completed', async () => {
      await updateValueAndEmit('token-complete', ['tokenA', ['5', '10']]);

      expect(getLastEmittedFilters()).toEqual({ tokenA: ['5', '10'] });
    });

    it('maintains other filters when adding a new token', async () => {
      await updateValueAndEmit('token-complete', ['tokenA', ['5']]);
      await updateValueAndEmit('token-complete', ['tokenA', ['5']], ['tokenB', ['15']]);

      expect(getLastEmittedFilters()).toEqual({
        tokenA: ['5'],
        tokenB: ['15'],
      });
    });

    it('updates existing filter when token is modified', async () => {
      await updateValueAndEmit('token-complete', ['tokenA', ['5', '10']]);
      await updateValueAndEmit('token-complete', ['tokenA', ['20']]);

      expect(wrapper.emitted('filters-changed')).toHaveLength(3);
      expect(getLastEmittedFilters()).toEqual({ tokenA: ['20'] });
    });

    it('removes only the destroyed token while maintaining others', async () => {
      await updateValueAndEmit('token-complete', ['tokenA', ['5']], ['tokenB', ['15']]);
      await updateValueAndEmit('token-destroy', ['tokenB', ['15']]);

      expect(getLastEmittedFilters()).toEqual({ tokenB: ['15'] });
    });

    it('emits empty filters when last token is destroyed', async () => {
      await updateValueAndEmit('token-complete', ['tokenA', ['5']]);
      await updateValueAndEmit('token-destroy');

      expect(getLastEmittedFilters()).toEqual({});
    });

    it('removes ALL_ID value from token value', async () => {
      await updateValueAndEmit('token-complete', ['tokenA', [ALL_ID]]);

      expect(getLastEmittedFilters()).toEqual({ tokenA: [] });
    });

    it('emits empty filters on clear', async () => {
      await updateValueAndEmit('token-complete', ['tokenA', ['5', '10']]);
      await updateValueAndEmit('clear', []);

      expect(getLastEmittedFilters()).toEqual({});
    });
  });

  describe('sync from url parameters on component create', () => {
    it('initializes filters from URL parameters on mount', async () => {
      setWindowLocation('?tokenA=5,10&tokenB=20');
      createWrapper();
      await nextTick();

      expect(wrapper.emitted('filters-changed')).toHaveLength(1);
      expect(getLastEmittedFilters()).toEqual({
        tokenA: ['5', '10'],
        tokenB: ['20'],
      });
    });

    it('sets filtered search value from URL parameters', () => {
      setWindowLocation('?tokenA=5,10');
      createWrapper();

      expect(findFilteredSearch().props('value')).toEqual([
        {
          type: 'tokenA',
          value: {
            data: ['5', '10'],
            operator: '||',
          },
        },
      ]);
    });

    it('initializes with != operator from not[type] URL parameter', () => {
      setWindowLocation('?not[tokenA]=5,10');
      createWrapper();

      expect(findFilteredSearch().props('value')).toEqual([
        {
          type: 'tokenA',
          value: {
            data: ['5', '10'],
            operator: '!=',
          },
        },
      ]);
    });

    it('prefers include param over exclude param when both are present', () => {
      setWindowLocation('?tokenA=5&not[tokenA]=10');
      createWrapper();

      expect(findFilteredSearch().props('value')).toEqual([
        {
          type: 'tokenA',
          value: {
            data: ['5'],
            operator: '||',
          },
        },
      ]);
    });

    it('ignores URL parameters for unrecognized tokens', async () => {
      setWindowLocation('?tokenA=5,10&unknownToken=20');
      createWrapper();
      await nextTick();

      expect(getLastEmittedFilters()).toEqual({ tokenA: ['5', '10'] });
    });

    it('ignores empty URL parameter values', async () => {
      setWindowLocation('?tokenA=');
      createWrapper();
      await nextTick();

      expect(getLastEmittedFilters()).toEqual({});
      expect(findFilteredSearch().props('value')).toEqual([]);
    });

    it('emits url-params-changed on initialization with valid tokens', () => {
      setWindowLocation('?tokenA=5,10');
      createWrapper();

      expect(wrapper.emitted('url-params-changed')).toHaveLength(1);
    });
  });

  describe('token transform functions', () => {
    describe('transformFilters', () => {
      it('uses token transformFilters when available', async () => {
        createWrapper({ tokens: [TEST_TOKEN_WITH_TRANSFORMS] });

        await updateValueAndEmit('token-complete', ['tokenWithTransforms', ['a', 'b']]);

        expect(getLastEmittedFilters()).toEqual({
          transformedKey: ['transformed_a', 'transformed_b'],
        });
      });

      it('passes operator to token transformFilters', async () => {
        createWrapper({ tokens: [TEST_TOKEN_WITH_TRANSFORMS] });

        await updateValueAndEmit('token-complete', ['tokenWithTransforms', ['a'], '!=']);

        expect(getLastEmittedFilters()).toEqual({
          transformedKey: ['not_transformed_a'],
        });
      });

      it('passes accumulating filters to token transformFilters', async () => {
        createWrapper({
          tokens: [TEST_TOKEN_A_DEFINITION, TEST_TOKEN_WITH_TRANSFORMS],
        });

        await updateValueAndEmit(
          'token-complete',
          ['tokenA', ['5']],
          ['tokenWithTransforms', ['a']],
        );

        expect(getLastEmittedFilters()).toEqual({
          tokenA: ['5'],
          transformedKey: ['transformed_a'],
        });
      });

      it('falls back to default behavior when transformFilters is not defined', async () => {
        createWrapper();

        await updateValueAndEmit('token-complete', ['tokenA', ['5', '10']]);

        expect(getLastEmittedFilters()).toEqual({ tokenA: ['5', '10'] });
      });
    });

    describe('transformQueryParams', () => {
      it('uses token transformQueryParams when available', async () => {
        createWrapper({ tokens: [TEST_TOKEN_WITH_TRANSFORMS] });

        await updateValueAndEmit('token-complete', ['tokenWithTransforms', ['a', 'b']]);

        expect(getLastEmittedUrlParams()).toMatchObject({
          tokenWithTransforms: 'param_a|param_b',
        });
      });

      it('forwards the token definition to transformQueryParams', async () => {
        const transformQueryParams = jest.fn().mockReturnValue('');
        const tokenDef = {
          ...TEST_TOKEN_WITH_TRANSFORMS,
          token: markRaw({ transformQueryParams }),
        };
        createWrapper({ tokens: [tokenDef] });

        await updateValueAndEmit('token-complete', ['tokenWithTransforms', ['a']]);

        expect(transformQueryParams).toHaveBeenCalledWith(['a'], tokenDef);
      });

      it('falls back to comma-separated values when transformQueryParams is not defined', async () => {
        createWrapper();

        await updateValueAndEmit('token-complete', ['tokenA', ['5', '10']]);

        expect(getLastEmittedUrlParams()).toMatchObject({
          tokenA: '5,10',
        });
      });
    });

    describe('defaultValues', () => {
      it('uses default values when no URL params exist for the token', () => {
        createWrapper({ tokens: [TEST_TOKEN_WITH_DEFAULTS] });

        expect(findFilteredSearch().props('value')).toEqual([
          {
            type: 'tokenWithDefaults',
            value: {
              data: ['default1', 'default2'],
              operator: '||',
            },
          },
        ]);
      });

      it('emits default values in filters-changed on mount', () => {
        createWrapper({ tokens: [TEST_TOKEN_WITH_DEFAULTS] });

        expect(getLastEmittedFilters()).toEqual({
          tokenWithDefaults: ['default1', 'default2'],
        });
      });

      it('emits undefined for default values in url-params-changed', () => {
        createWrapper({ tokens: [TEST_TOKEN_WITH_DEFAULTS] });

        expect(getLastEmittedUrlParams()).toMatchObject({
          tokenWithDefaults: undefined,
        });
      });

      it('prefers URL params over default values', () => {
        setWindowLocation('?tokenWithDefaults=custom1');
        createWrapper({ tokens: [TEST_TOKEN_WITH_DEFAULTS] });

        expect(findFilteredSearch().props('value')).toEqual([
          {
            type: 'tokenWithDefaults',
            value: {
              data: ['custom1'],
              operator: '||',
            },
          },
        ]);
      });

      it('returns empty array when token has no defaultValues function', () => {
        createWrapper();

        expect(findFilteredSearch().props('value')).toEqual([]);
      });
    });

    describe('context passing', () => {
      const TEST_TOKEN_WITH_CONTEXT_DEFAULTS = {
        type: 'tokenWithContextDefaults',
        title: 'Token With Context Defaults',
        multiSelect: true,
        unique: true,
        token: markRaw({
          defaultValues: (context) => (context?.defaultBranchContext ? ['branch_default'] : []),
        }),
        operators: OPERATORS_OR,
      };

      it('passes context to defaultValues', () => {
        createWrapper({
          tokens: [TEST_TOKEN_WITH_CONTEXT_DEFAULTS],
          provide: { defaultBranchContext: { id: '1', name: 'main' } },
        });

        expect(findFilteredSearch().props('value')).toEqual([
          {
            type: 'tokenWithContextDefaults',
            value: { data: ['branch_default'], operator: '||' },
          },
        ]);
      });

      it('passes context spread into transformFilters options', async () => {
        createWrapper({
          tokens: [TEST_TOKEN_WITH_TRANSFORMS],
          provide: { dashboardType: 'group' },
        });

        await updateValueAndEmit('token-complete', ['tokenWithTransforms', ['a']]);

        expect(getLastEmittedFilters()).toEqual({
          transformedKey: ['transformed_a'],
          dashboardType: 'group',
        });
      });

      it('passes the token definition as config to defaultValues', () => {
        const TEST_TOKEN_WITH_CONFIG_DEFAULT = {
          type: 'tokenWithConfigDefault',
          title: 'Token With Config Default',
          multiSelect: true,
          unique: true,
          defaultValue: ['from_config'],
          token: markRaw({
            defaultValues: ({ config } = {}) => config?.defaultValue ?? [],
          }),
          operators: OPERATORS_OR,
        };

        createWrapper({ tokens: [TEST_TOKEN_WITH_CONFIG_DEFAULT] });

        expect(findFilteredSearch().props('value')).toEqual([
          {
            type: 'tokenWithConfigDefault',
            value: { data: ['from_config'], operator: '||' },
          },
        ]);
      });
    });

    describe('parseQueryParams', () => {
      it('uses token parseQueryParams when available', () => {
        setWindowLocation('?tokenWithTransforms=param_a,param_b');
        createWrapper({ tokens: [TEST_TOKEN_WITH_TRANSFORMS] });

        expect(findFilteredSearch().props('value')).toEqual([
          {
            type: 'tokenWithTransforms',
            value: {
              data: ['a', 'b'],
              operator: '||',
            },
          },
        ]);
      });

      it('forwards the token definition to parseQueryParams', () => {
        const parseQueryParams = jest.fn().mockReturnValue(['x']);
        const tokenDef = {
          ...TEST_TOKEN_WITH_TRANSFORMS,
          token: markRaw({ parseQueryParams }),
        };
        setWindowLocation('?tokenWithTransforms=param_a');
        createWrapper({ tokens: [tokenDef] });

        expect(parseQueryParams).toHaveBeenCalledWith(['param_a'], tokenDef);
      });

      it('falls back to raw values when parseQueryParams is not defined', () => {
        setWindowLocation('?tokenA=5,10');
        createWrapper();

        expect(findFilteredSearch().props('value')).toEqual([
          {
            type: 'tokenA',
            value: {
              data: ['5', '10'],
              operator: '||',
            },
          },
        ]);
      });
    });
  });

  describe('url-params-changed event', () => {
    beforeEach(createWrapper);

    it('emits params for added filter', async () => {
      await updateValueAndEmit('token-complete', ['tokenA', ['5', '10']]);

      expect(getLastEmittedUrlParams()).toMatchObject({
        tokenA: '5,10',
      });
    });

    it('emits params for multiple tokens', async () => {
      await updateValueAndEmit('token-complete', ['tokenA', ['5']], ['tokenB', ['15', '20']]);

      expect(getLastEmittedUrlParams()).toMatchObject({
        tokenA: '5',
        tokenB: '15,20',
      });
    });

    it('emits negated token values with not[type] key', async () => {
      await updateValueAndEmit('token-complete', ['tokenA', ['5', '10'], '!=']);

      expect(getLastEmittedUrlParams()).toMatchObject({
        tokenA: undefined,
        'not[tokenA]': '5,10',
      });
    });

    it('sets removed token param to undefined on destroy', async () => {
      await updateValueAndEmit('token-complete', ['tokenA', ['5']], ['tokenB', ['15']]);
      await updateValueAndEmit('token-destroy', ['tokenB', ['15']]);

      expect(getLastEmittedUrlParams()).toMatchObject({
        tokenA: undefined,
        tokenB: '15',
      });
    });

    it('sets all filter params to undefined on clear', async () => {
      await updateValueAndEmit('token-complete', ['tokenA', ['5']], ['tokenB', ['15']]);
      await updateValueAndEmit('clear', []);

      expect(getLastEmittedUrlParams()).toMatchObject({
        tokenA: undefined,
        tokenB: undefined,
      });
    });

    it('emits url-params-changed on mount', () => {
      expect(wrapper.emitted('url-params-changed')).toHaveLength(1);
    });
  });
});
