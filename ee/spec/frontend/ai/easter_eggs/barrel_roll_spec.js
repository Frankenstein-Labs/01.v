import { isBarrelRollCommand, maybeDoBarrelRoll } from 'ee/ai/easter_eggs/barrel_roll';

describe('barrel_roll easter egg', () => {
  describe('isBarrelRollCommand', () => {
    it.each([
      ['do a barrel roll', true],
      ['  Do A Barrel Roll  ', true],
      ['DO A BARREL ROLL', true],
      ['do a barrel roll please', false],
      ['/reset', false],
      ['', false],
      [null, false],
      [undefined, false],
    ])('for prompt %p returns %p', (prompt, expected) => {
      expect(isBarrelRollCommand(prompt)).toBe(expected);
    });
  });

  describe('maybeDoBarrelRoll', () => {
    const findInjectedStyles = () =>
      Array.from(document.head.querySelectorAll('style')).filter((el) =>
        el.textContent.includes('duo-barrel-roll'),
      );

    afterEach(() => {
      document.body.style.animation = '';
      findInjectedStyles().forEach((el) => el.remove());
    });

    describe('when the prompt is not the command', () => {
      it('returns false without touching the DOM', () => {
        expect(maybeDoBarrelRoll('what is a merge request')).toBe(false);
        expect(findInjectedStyles()).toHaveLength(0);
        expect(document.body.style.animation).toBe('');
      });
    });

    describe('when the prompt is the command', () => {
      it('returns true', () => {
        expect(maybeDoBarrelRoll('do a barrel roll')).toBe(true);
      });

      it('injects a keyframe and animates the body', () => {
        maybeDoBarrelRoll('do a barrel roll');

        expect(findInjectedStyles()).toHaveLength(1);
        expect(document.body.style.animation).toContain('duo-barrel-roll');
      });

      it('removes the animation and injected style once the animation ends', () => {
        maybeDoBarrelRoll('do a barrel roll');

        document.body.dispatchEvent(new Event('animationend'));

        expect(document.body.style.animation).toBe('');
        expect(findInjectedStyles()).toHaveLength(0);
      });

      it('ignores repeat triggers while a roll is already in flight', () => {
        maybeDoBarrelRoll('do a barrel roll');
        maybeDoBarrelRoll('do a barrel roll');

        expect(findInjectedStyles()).toHaveLength(1);
      });

      it('does not animate when the user prefers reduced motion', () => {
        jest.spyOn(window, 'matchMedia').mockReturnValue({ matches: true });

        expect(maybeDoBarrelRoll('do a barrel roll')).toBe(true);
        expect(findInjectedStyles()).toHaveLength(0);
        expect(document.body.style.animation).toBe('');
      });
    });
  });
});
