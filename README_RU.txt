Smart Dating Europe — обновление

1. Сначала сохраните резервные копии текущих файлов GitHub.
2. В Supabase SQL Editor выполните supabase_sde.sql один раз. Он создаст кошельки и подарки, включая приветственные 50 SDE.
3. В Supabase Authentication → URL Configuration добавьте разрешённый Redirect URL: https://smartdatingeurope.github.io/smartdatingeurope27/reset-password.html
4. Загрузите index.html, profile.html, chat.html, wallet.html, reset-password.html в корень репозитория GitHub (заменив одноимённые).
5. Проверьте вход, анкету, чат, подарки и сброс пароля на тестовых аккаунтах.
6. Покупка токенов отключена. Не принимать оплату до реализации серверного подтверждения платежа и юридической проверки.
7. Проверить RLS существующей таблицы messages отдельно: этот пакет не изменяет её политики.
8. В этом пакете нет фотографий в чате, лайков, уведомлений и активной VIP-подписки: их нужно внедрять отдельно.
