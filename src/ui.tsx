import { CaretLeft } from '@phosphor-icons/react'
import type { ButtonHTMLAttributes, ReactNode } from 'react'

export const cx = (...c: (string | false | null | undefined)[]) => c.filter(Boolean).join(' ')

export function Button({
  variant = 'primary',
  className,
  children,
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: 'primary' | 'secondary' | 'ghost' }) {
  return (
    <button
      {...rest}
      className={cx(
        'inline-flex h-12 items-center justify-center gap-2 rounded-full px-5 text-[15.5px] font-medium whitespace-nowrap transition-[transform,background-color,opacity] duration-200 active:scale-[0.97] disabled:opacity-45 disabled:active:scale-100',
        variant === 'primary' && 'bg-accent text-accent-ink',
        variant === 'secondary' && 'bg-surface-2 text-ink',
        variant === 'ghost' && 'h-10 px-3 text-accent',
        className,
      )}
    >
      {children}
    </button>
  )
}

export function Card({ className, children }: { className?: string; children: ReactNode }) {
  return <div className={cx('rounded-card bg-surface p-5 shadow-card', className)}>{children}</div>
}

/** Page frame. Sub-pages get a back link instead of the eyebrow. */
export function Page({
  eyebrow,
  title,
  onBack,
  children,
}: {
  eyebrow?: string
  title: string
  onBack?: () => void
  children: ReactNode
}) {
  return (
    <div className="pt-safe pb-safe mx-auto w-full max-w-xl px-4">
      {onBack ? (
        <button onClick={onBack} className="-ml-1 flex h-9 items-center gap-0.5 rounded-full pr-3 text-[16px] text-accent">
          <CaretLeft size={20} weight="bold" />
          Geri
        </button>
      ) : (
        <p className="flex h-9 items-center text-[14px] font-medium tracking-wide text-muted">{eyebrow}</p>
      )}
      <h1 className="pb-5 text-[30px] leading-tight font-[680] tracking-[-0.03em]">{title}</h1>
      {children}
    </div>
  )
}

export function FieldLabel({ n, children, htmlFor }: { n: number; children: ReactNode; htmlFor?: string }) {
  return (
    <label htmlFor={htmlFor} className="mb-2 flex items-center gap-2.5 text-[15.5px] font-[580]">
      <span className="grid size-6 shrink-0 place-items-center rounded-full bg-accent-soft text-[13px] font-semibold text-accent-deep">
        {n}
      </span>
      {children}
    </label>
  )
}

export const fieldClass =
  'w-full rounded-field border border-line bg-surface-2 px-3.5 py-3 text-[16px] leading-snug text-ink placeholder:text-muted/70 focus:border-accent focus:outline-none'
