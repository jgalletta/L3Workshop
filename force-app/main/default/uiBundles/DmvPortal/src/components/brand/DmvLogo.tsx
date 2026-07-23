/*
 * DMV brand mark — a shield (authority / trust, the universal motor-vehicle
 * agency motif) enclosing a stylized highway vanishing toward a horizon, with
 * a gold sky band (the CA state accent). Geometric, crisp at any size.
 * `variant="light"` inverts the shield fill for dark backgrounds (footer).
 */
export function DmvLogo({
  className = '',
  variant = 'dark',
}: {
  className?: string;
  variant?: 'dark' | 'light';
}) {
  const shieldFill = variant === 'light' ? '#ffffff' : '#0a3161';
  const shieldStroke = variant === 'light' ? '#ffffff' : '#0a3161';
  const roadInk = variant === 'light' ? '#0a3161' : '#ffffff';
  const skyBand = '#fdb81e';
  const roadColor = variant === 'light' ? '#0a3161' : '#123f78';

  return (
    <svg
      viewBox="0 0 48 48"
      className={className}
      role="img"
      aria-label="Department of Motor Vehicles logo"
    >
      <defs>
        <clipPath id="dmv-shield-clip">
          <path d="M24 3 6 9v15c0 11.5 7.8 18.6 18 21 10.2-2.4 18-9.5 18-21V9L24 3Z" />
        </clipPath>
      </defs>

      {/* Shield body */}
      <path
        d="M24 3 6 9v15c0 11.5 7.8 18.6 18 21 10.2-2.4 18-9.5 18-21V9L24 3Z"
        fill={shieldFill}
        stroke={shieldStroke}
        strokeWidth="1.5"
        strokeLinejoin="round"
      />

      {/* Scene clipped to shield */}
      <g clipPath="url(#dmv-shield-clip)">
        {/* Gold sky band */}
        <rect x="6" y="9" width="36" height="10" fill={skyBand} />
        {/* Road surface — trapezoid vanishing to horizon */}
        <path d="M17 45 22.5 19h3L31 45H17Z" fill={roadColor} opacity="0.9" />
        {/* Center dashed lane markings */}
        <g fill={roadInk}>
          <rect x="23.4" y="21" width="1.2" height="3" rx="0.6" />
          <rect x="23.3" y="27" width="1.4" height="3.4" rx="0.7" />
          <rect x="23.15" y="34" width="1.7" height="4" rx="0.85" />
          <rect x="22.95" y="42" width="2.1" height="2.6" rx="1" />
        </g>
      </g>
    </svg>
  );
}
