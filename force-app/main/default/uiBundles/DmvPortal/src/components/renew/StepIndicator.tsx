import { Check } from 'lucide-react';

/**
 * Horizontal step indicator for the renewal wizard. Shows completed (check),
 * current (filled), and upcoming (outline) states with a connecting track.
 */
export function StepIndicator({
  steps,
  currentStep,
}: {
  steps: string[];
  currentStep: number; // 1-based
}) {
  return (
    <nav aria-label="Progress" className="mb-8">
      <ol className="flex items-center">
        {steps.map((label, idx) => {
          const stepNum = idx + 1;
          const isComplete = stepNum < currentStep;
          const isCurrent = stepNum === currentStep;
          const isLast = idx === steps.length - 1;

          return (
            <li
              key={label}
              className={`flex items-center ${isLast ? '' : 'flex-1'}`}
            >
              <div className="flex flex-col items-center gap-2">
                <div
                  className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full border-2 text-sm font-semibold transition-all ${
                    isComplete
                      ? 'border-dmv-blue bg-dmv-blue text-white'
                      : isCurrent
                        ? 'border-dmv-blue bg-white text-dmv-blue shadow-dmv-glow'
                        : 'border-dmv-line bg-white text-dmv-mist'
                  }`}
                  aria-current={isCurrent ? 'step' : undefined}
                >
                  {isComplete ? <Check className="h-4 w-4" /> : stepNum}
                </div>
                <span
                  className={`hidden text-xs font-medium sm:block ${
                    isCurrent
                      ? 'text-dmv-navy'
                      : isComplete
                        ? 'text-dmv-blue'
                        : 'text-dmv-mist'
                  }`}
                >
                  {label}
                </span>
              </div>
              {!isLast && (
                <div
                  className={`mx-2 h-0.5 flex-1 rounded-full transition-colors ${
                    isComplete ? 'bg-dmv-blue' : 'bg-dmv-line'
                  }`}
                />
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
