(function () {
  const catalog = {
    JEE: {
      Maths: [
        "Sets, Relations and Functions",
        "Complex Numbers and Quadratic Equations",
        "Limit, Continuity and Differentiability",
        "Integral Calculus",
        "Vector Algebra"
      ],
      Physics: [
        "Kinematics",
        "Laws of Motion",
        "Work, Energy and Power",
        "Electrostatics",
        "Optics"
      ],
      Chemistry: [
        "Atomic Structure",
        "Chemical Bonding and Molecular Structure",
        "Chemical Thermodynamics",
        "Chemical Kinetics",
        "Basic Principles of Organic Chemistry"
      ]
    },
    NEET: {
      Biology: [
        "Cell Structure",
        "Genetics",
        "Human Physiology",
        "Plant Physiology",
        "Ecology"
      ],
      Physics: [
        "Kinematics",
        "Laws of Motion",
        "Thermodynamics",
        "Electrostatics",
        "Optics"
      ],
      Chemistry: [
        "Atomic Structure",
        "Chemical Bonding",
        "Equilibrium",
        "Organic Basics",
        "Biomolecules"
      ]
    }
  };

  const stems = [
    "Which statement is most accurate about",
    "Identify the correct option related to",
    "Which of the following best explains",
    "Choose the most appropriate fact about",
    "In the context of basics, which point is correct for",
    "What is the most suitable interpretation of",
    "Pick the correct conceptual statement for",
    "Which option is generally accepted for",
    "Select the right answer regarding",
    "Which of these is correct for"
  ];

  const wrongPrefixes = [
    "A common misconception is that",
    "An incorrect interpretation says",
    "A confusing but wrong claim is",
    "A less accurate statement is",
    "A misleading statement suggests"
  ];

  function seededRand(seed) {
    let h = 2166136261;
    const s = String(seed || "");
    for (let i = 0; i < s.length; i += 1) {
      h ^= s.charCodeAt(i);
      h += (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24);
    }
    return () => {
      h += 0x6d2b79f5;
      let t = h;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function shuffle(list, rnd) {
    const arr = list.slice();
    for (let i = arr.length - 1; i > 0; i -= 1) {
      const j = Math.floor(rnd() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  }

  function generateQuestions(exam, subject, chapter, track, count) {
    const total = Math.max(1, Number(count) || 10);
    const rnd = seededRand(`${exam}::${subject}::${chapter}::${track}`);
    const levelLabel = String(track || "Practice");
    const output = [];
    for (let i = 0; i < total; i += 1) {
      const stem = stems[i % stems.length];
      const correct = `${chapter} principle ${i + 1} is applied with proper conditions in ${subject}.`;
      const choices = [
        correct,
        `${wrongPrefixes[i % wrongPrefixes.length]} ${chapter} never depends on context.`,
        `${wrongPrefixes[(i + 1) % wrongPrefixes.length]} ${chapter} can be solved without core assumptions.`,
        `${wrongPrefixes[(i + 2) % wrongPrefixes.length]} ${chapter} is identical to every other chapter.`
      ];
      const mixed = shuffle(choices, rnd);
      output.push({
        prompt: `${stem} ${chapter} (${exam} • ${subject} • ${levelLabel})?`,
        choices: mixed,
        answer: correct
      });
    }
    return output;
  }

  window.curriculumData = {
    catalog,
    generateQuestions
  };
})();
