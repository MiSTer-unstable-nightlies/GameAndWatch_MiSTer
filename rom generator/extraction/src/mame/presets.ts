import { CPUType, PresetDefinition } from "./types";

const MAIN_CALL_REGEX = /(.*)\(config,(.*)\)/;

type PresetFactory = (...args: any[]) => PresetDefinition;

export const createPreset = (
  constructorBody: string,
  name: string
): PresetDefinition | undefined => {
  const lines = constructorBody
    .trim()
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  if (lines.length > 1) {
    console.log(
      `Device ${name} may require additional configuration. It performs extra actions in its constructor`
    );
  }

  const inheritedKonamiScreen = extractInheritedKonamiScreen(lines);
  if (inheritedKonamiScreen) {
    return inheritedKonamiScreen;
  }

  const match = lines[0].match(MAIN_CALL_REGEX);

  if (!match) {
    console.log(`Could not extract constructor for device ${name}`);
    return;
  }

  const presetFunc = choosePreset(match[1]);

  if (!presetFunc) {
    console.log(
      `Could not find matching preset ${match[1]} for device ${name}`
    );
    return;
  }

  const args = parsePresetArgs(match[2]);
  if (!args) {
    console.log(
      `Unhandled constructor arguments ${match[2]} for device ${name}`
    );
    return;
  }

  return presetFunc(...args);
};

const extractInheritedKonamiScreen = (
  lines: string[]
): PresetDefinition | undefined => {
  if (!lines.some((line) => line.startsWith("ktmnt2(config)"))) {
    return undefined;
  }

  const screenLine = lines.find((line) =>
    line.startsWith("mcfg_svg_screen(config,")
  );

  if (!screenLine) {
    return undefined;
  }

  const match = screenLine.match(MAIN_CALL_REGEX);
  if (!match) {
    return undefined;
  }

  const args = parsePresetArgs(match[2]);
  if (!args || args.length < 2) {
    return undefined;
  }

  // kst25/ktopgun2 inherit the Konami sample-driver machine config from
  // ktmnt2, then replace only the SVG screen size. The CPU is still SM511.
  return sm511_common(args[0], args[1]);
};

const parsePresetArgs = (argString: string): number[] | undefined => {
  const args = argString
    .split(",")
    .map((s) => s.trim())
    .map((s) => {
      const division = isDivision(s);

      if (division) {
        return division.dividend / division.divisor;
      } else if (isOnlyDigits(s)) {
        return parseInt(s, 10);
      }

      return s;
    });

  for (const arg of args) {
    if (typeof arg === "string") {
      return undefined;
    }
  }

  return args as number[];
};

const isOnlyDigits = (value: string) => /^-?\d+$/.test(value);

const isDivision = (
  value: string
):
  | {
      dividend: number;
      divisor: number;
    }
  | undefined => {
  const match = value.match(/^(\d+)\/(\d+)/);

  if (match) {
    return {
      dividend: parseInt(match[1]),
      divisor: parseInt(match[2]),
    };
  }

  return undefined;
};

const choosePreset = (name: string): PresetFactory | undefined => {
  switch (name) {
    case "sm5a_common":
      return sm5a_common;
    case "kb1013vk12_common":
      return kb1013vk12_common;
    case "sm510_common":
      return sm510_common;
    case "sm511_common":
      return sm511_common;
    case "sm530_common":
      return sm530_common;

    case "sm510_dualh":
      return sm510_dualh;
    case "sm510_dualv":
      return sm510_dualv;
    case "sm511_dualv":
      return sm511_dualv;
    case "sm511_tripleh":
      return sm511_tripleh;
    case "sm512_dualv":
      return sm512_dualv;

    case "sm510_tiger":
      return sm510_tiger;
    case "sm511_tiger1bit":
      return sm511_tiger1bit;
    case "sm511_tiger2bit":
      return sm511_tiger2bit;
  }

  return undefined;
};

/* Definitions */

const standard_single = (
  cpu: CPUType,
  width: number,
  height: number
): PresetDefinition => ({
  cpu,

  screen: {
    type: "single",

    width,
    height,
  },
});

const standard_dual_horiztonal = (
  cpu: CPUType,
  leftWidth: number,
  leftHeight: number,
  rightWidth: number,
  rightHeight: number
): PresetDefinition => ({
  cpu,

  screen: {
    type: "dualHorizontal",

    left: {
      width: leftWidth,
      height: leftHeight,
    },

    right: {
      width: rightWidth,
      height: rightHeight,
    },
  },
});

const standard_dual_vertical = (
  cpu: CPUType,
  topWidth: number,
  topHeight: number,
  bottomWidth: number,
  bottomHeight: number
): PresetDefinition => ({
  cpu,

  screen: {
    type: "dualVertical",

    top: {
      width: topWidth,
      height: topHeight,
    },

    bottom: {
      width: bottomWidth,
      height: bottomHeight,
    },
  },
});

const standard_triple_horiztonal = (
  cpu: CPUType,
  leftWidth: number,
  leftHeight: number,
  middleWidth: number,
  middleHeight: number,
  rightWidth: number,
  rightHeight: number
): PresetDefinition => ({
  cpu,

  screen: {
    type: "tripleHorizontal",

    left: {
      width: leftWidth,
      height: leftHeight,
    },

    middle: {
      width: middleWidth,
      height: middleHeight,
    },

    right: {
      width: rightWidth,
      height: rightHeight,
    },
  },
});

/* Standard */

const sm5a_common = (width: number, height: number): PresetDefinition =>
  standard_single("sm5a", width, height);

const kb1013vk12_common = (width: number, height: number): PresetDefinition =>
  standard_single("kb1013vk12", width, height);

const sm510_common = (width: number, height: number): PresetDefinition =>
  standard_single("sm510", width, height);

const sm511_common = (width: number, height: number): PresetDefinition =>
  standard_single("sm511", width, height);

const sm530_common = (width: number, height: number): PresetDefinition =>
  standard_single("sm530", width, height);

/* Multi-screen */

const sm510_dualh = (
  leftWidth: number,
  leftHeight: number,
  rightWidth: number,
  rightHeight: number
): PresetDefinition =>
  standard_dual_horiztonal(
    "sm510",
    leftWidth,
    leftHeight,
    rightWidth,
    rightHeight
  );

const sm510_dualv = (
  topWidth: number,
  topHeight: number,
  bottomWidth: number,
  bottomHeight: number
): PresetDefinition =>
  standard_dual_vertical(
    "sm510",
    topWidth,
    topHeight,
    bottomWidth,
    bottomHeight
  );

const sm511_dualv = (
  topWidth: number,
  topHeight: number,
  bottomWidth: number,
  bottomHeight: number
): PresetDefinition =>
  standard_dual_vertical(
    "sm511",
    topWidth,
    topHeight,
    bottomWidth,
    bottomHeight
  );

const sm511_tripleh = (
  leftWidth: number,
  leftHeight: number,
  middleWidth: number,
  middleHeight: number,
  rightWidth: number,
  rightHeight: number
): PresetDefinition =>
  standard_triple_horiztonal(
    "sm511",
    leftWidth,
    leftHeight,
    middleWidth,
    middleHeight,
    rightWidth,
    rightHeight
  );

const sm512_dualv = (
  topWidth: number,
  topHeight: number,
  bottomWidth: number,
  bottomHeight: number
): PresetDefinition =>
  standard_dual_vertical(
    "sm512",
    topWidth,
    topHeight,
    bottomWidth,
    bottomHeight
  );

/* Tiger */

const sm510_tiger = (width: number, height: number): PresetDefinition =>
  standard_single("sm510_tiger", width, height);

const sm511_tiger1bit = (width: number, height: number): PresetDefinition =>
  standard_single("sm511_tiger1bit", width, height);

const sm511_tiger2bit = (width: number, height: number): PresetDefinition =>
  standard_single("sm511_tiger2bit", width, height);
