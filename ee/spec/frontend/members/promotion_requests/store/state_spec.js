import createState from 'ee/members/promotion_requests/store/state';

describe('Promotion requests store state', () => {
  it('inits the state', () => {
    const state = createState({ enabled: true, totalItems: 2 });
    expect(state).toEqual({
      enabled: true,
      pagination: { totalItems: 2 },
    });
  });

  it('applies defaults', () => {
    const state = createState({});
    expect(state).toEqual({
      enabled: false,
      pagination: { totalItems: 0 },
    });
  });
});
