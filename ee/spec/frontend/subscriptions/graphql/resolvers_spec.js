import Api from 'ee/api';
import { gitLabResolvers } from 'ee/subscriptions/graphql/resolvers';
import { ERROR_FETCHING_COUNTRIES, ERROR_FETCHING_STATES } from 'ee/subscriptions/constants';
import { createAlert } from '~/alert';

jest.mock('~/alert');

jest.mock('ee/api', () => {
  return {
    fetchCountries: jest.fn(),
    fetchStates: jest.fn(),
  };
});

const countries = [
  ['United States of America', 'US', 'US', '1'],
  ['Uruguay', 'UY', 'UY', '598'],
];

const states = { California: 'CA' };

describe('~/subscriptions/graphql/resolvers', () => {
  describe('Query', () => {
    describe('countries', () => {
      describe('on success', () => {
        beforeEach(() => {
          Api.fetchCountries.mockResolvedValue({ data: countries });
        });

        it('returns an array of countries with typename', async () => {
          const result = await gitLabResolvers.Query.countries();

          expect(createAlert).not.toHaveBeenCalled();
          expect(result).toStrictEqual([
            {
              name: 'United States of America',
              id: 'US',
              flag: 'US',
              internationalDialCode: '1',
              __typename: 'Country',
            },
            {
              name: 'Uruguay',
              id: 'UY',
              flag: 'UY',
              internationalDialCode: '598',
              __typename: 'Country',
            },
          ]);
        });
      });

      describe('on error', () => {
        beforeEach(() => {
          Api.fetchCountries.mockRejectedValue();
        });

        it('shows an alert message', async () => {
          await gitLabResolvers.Query.countries();

          expect(createAlert).toHaveBeenCalledWith({ message: ERROR_FETCHING_COUNTRIES });
        });
      });
    });

    describe('states', () => {
      describe('on success', () => {
        beforeEach(() => {
          Api.fetchStates.mockResolvedValue({ data: states });
        });

        it('returns an array of states with typename', async () => {
          const result = await gitLabResolvers.Query.states(null, { countryId: 1 });

          expect(createAlert).not.toHaveBeenCalled();
          expect(result).toStrictEqual([{ id: 'CA', name: 'California', __typename: 'State' }]);
        });
      });

      describe('on error', () => {
        beforeEach(() => {
          Api.fetchStates.mockRejectedValue();
        });

        it('shows an alert message', async () => {
          await gitLabResolvers.Query.states(null, { countryId: 1 });

          expect(createAlert).toHaveBeenCalledWith({ message: ERROR_FETCHING_STATES });
        });
      });
    });
  });
});
