-- Smart Dating Europe: внутренние баллы SDE и подарки. Выполняется один раз в Supabase SQL Editor.
-- ВАЖНО: перед запуском проверьте существующие объекты. Скрипт не удаляет таблицы.
create table if not exists public.sde_wallets (
 user_id uuid primary key references auth.users(id) on delete cascade,
 balance bigint not null default 0 check(balance >= 0),
 created_at timestamptz not null default now()
);
create table if not exists public.sde_gifts (
 id bigint generated always as identity primary key,
 sender_id uuid not null references auth.users(id),
 receiver_id uuid not null references auth.users(id),
 gift_name text not null,
 price bigint not null check(price > 0),
 created_at timestamptz not null default now(),
 check(sender_id <> receiver_id)
);
create table if not exists public.sde_ledger (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id),
 delta bigint not null,
 reason text not null,
 gift_id bigint references public.sde_gifts(id),
 created_at timestamptz not null default now()
);
alter table public.sde_wallets enable row level security;
alter table public.sde_gifts enable row level security;
alter table public.sde_ledger enable row level security;
revoke all on public.sde_wallets,public.sde_gifts,public.sde_ledger from anon,authenticated;
grant select on public.sde_wallets,public.sde_gifts,public.sde_ledger to authenticated;
drop policy if exists sde_wallet_owner_read on public.sde_wallets;
create policy sde_wallet_owner_read on public.sde_wallets for select to authenticated using(user_id = (select auth.uid()));
drop policy if exists sde_gifts_participants_read on public.sde_gifts;
create policy sde_gifts_participants_read on public.sde_gifts for select to authenticated using(sender_id = (select auth.uid()) or receiver_id = (select auth.uid()));
drop policy if exists sde_ledger_owner_read on public.sde_ledger;
create policy sde_ledger_owner_read on public.sde_ledger for select to authenticated using(user_id = (select auth.uid()));
-- Подарок при первой регистрации: 50 SDE. Нельзя повторно получить через интерфейс.
create or replace function public.sde_create_wallet() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.sde_wallets(user_id,balance) values(new.id,50) on conflict(user_id) do nothing;
 if found then insert into public.sde_ledger(user_id,delta,reason) values(new.id,50,'welcome'); end if;
 return new;
end $$;
drop trigger if exists sde_new_user_wallet on auth.users;
create trigger sde_new_user_wallet after insert on auth.users for each row execute function public.sde_create_wallet();
-- Для ранее зарегистрированных участников: приветственные 50 SDE начисляются один раз.
with inserted as (
 insert into public.sde_wallets(user_id,balance)
 select id,50 from auth.users on conflict(user_id) do nothing returning user_id
)
insert into public.sde_ledger(user_id,delta,reason) select user_id,50,'welcome' from inserted;
-- Единственная разрешённая клиенту операция изменения баланса: атомарная отправка подарка.
create or replace function public.sde_send_gift(p_receiver uuid,p_gift_name text)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_sender uuid := (select auth.uid()); v_price bigint; v_id bigint;
begin
 if v_sender is null then raise exception 'Требуется вход'; end if;
 if p_receiver is null or p_receiver=v_sender then raise exception 'Неверный получатель'; end if;
 if not exists(select 1 from auth.users where id=p_receiver) then raise exception 'Получатель не найден'; end if;
 v_price:=case p_gift_name when 'Роза' then 10 when 'Букет' then 50 when 'Мишка' then 100 when 'Кольцо' then 200 when 'Бриллиант' then 500 when 'Корона' then 1000 else null end;
 if v_price is null then raise exception 'Неизвестный подарок'; end if;
 update public.sde_wallets set balance=balance-v_price where user_id=v_sender and balance>=v_price;
 if not found then raise exception 'Недостаточно SDE'; end if;
 insert into public.sde_gifts(sender_id,receiver_id,gift_name,price) values(v_sender,p_receiver,p_gift_name,v_price) returning id into v_id;
 insert into public.sde_ledger(user_id,delta,reason,gift_id) values(v_sender,-v_price,'gift_sent',v_id);
 return v_id;
end $$;
revoke all on function public.sde_send_gift(uuid,text) from public,anon;
grant execute on function public.sde_send_gift(uuid,text) to authenticated;
-- Пополнение за евро здесь намеренно отсутствует: его нужно реализовать
-- через серверный обработчик подтверждённых платежей с защитой от повторной обработки.
