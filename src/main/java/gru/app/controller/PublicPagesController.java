package gru.app.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class PublicPagesController {

    private final String supportEmail;

    public PublicPagesController(
            @Value("${gru.public.support-email:${GRU_SUPPORT_EMAIL:not-configured}}") String supportEmail
    ) {
        this.supportEmail = supportEmail == null || supportEmail.isBlank()
                ? "not-configured"
                : supportEmail.trim();
    }

    @GetMapping(value = "/privacy", produces = MediaType.TEXT_HTML_VALUE)
    public String privacy() {
        return page(
                "GRU Privacy Policy",
                """
                <h1>GRU Privacy Policy</h1>
                <p class=\"lead\">Effective: August 28, 2026</p>
                <h2>What GRU stores</h2>
                <p>GRU stores account information required to operate the service, including your account identifier and profile information. Messages and media that you choose to send are stored so they can be delivered and synchronized between participants.</p>
                <h2>How data is used</h2>
                <p>Data is used only to provide messaging, synchronization, safety, account management, reporting, blocking, and related GRU features. GRU does not sell personal data to advertisers.</p>
                <h2>Deletion</h2>
                <p>You can delete individual messages, chats, and your account from inside the app. Account deletion is designed to remove the account and associated server-side user data, subject to limited records that may need to be retained for abuse prevention or legal obligations.</p>
                <h2>Safety</h2>
                <p>Users can block accounts and report abusive content. Reports may contain the information necessary to investigate the reported interaction.</p>
                <h2>Security</h2>
                <p>GRU uses authenticated API access and encrypted transport in release builds. No internet service can guarantee absolute security.</p>
                <h2>Contact</h2>
                <p>Privacy and support contact: <a href=\"mailto:%s\">%s</a></p>
                """.formatted(escape(supportEmail), escape(supportEmail))
        );
    }

    @GetMapping(value = "/support", produces = MediaType.TEXT_HTML_VALUE)
    public String support() {
        return page(
                "GRU Support",
                """
                <h1>GRU Support</h1>
                <p class=\"lead\">gru — твой выход в мир</p>
                <h2>Connection</h2>
                <p>If GRU shows that realtime is reconnecting, check your internet connection and reopen the app. The service may need a short cold-start period on the community hosting tier.</p>
                <h2>Account & safety</h2>
                <p>Blocking, reporting, chat deletion and account deletion are available inside GRU. Use the Safety Center for account-related actions.</p>
                <h2>Media</h2>
                <p>Large uploads can take longer on the community infrastructure. Keep the app open until an upload reaches the sent state.</p>
                <h2>Contact</h2>
                <p>Email: <a href=\"mailto:%s\">%s</a></p>
                """.formatted(escape(supportEmail), escape(supportEmail))
        );
    }

    private String page(String title, String content) {
        return """
                <!doctype html>
                <html lang=\"en\">
                <head>
                  <meta charset=\"utf-8\">
                  <meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">
                  <title>%s</title>
                  <style>
                    :root{color-scheme:dark}body{margin:0;background:#070a10;color:#f7f8fb;font:16px -apple-system,BlinkMacSystemFont,\"SF Pro Text\",sans-serif;line-height:1.55}main{max-width:720px;margin:auto;padding:64px 24px 96px}h1{font-size:36px;letter-spacing:-1px;margin:0 0 8px}h2{margin-top:36px;font-size:18px}p{color:#b9bfcb}.lead{color:#7fe7ff}a{color:#7fe7ff}footer{margin-top:56px;color:#6e7685;font-size:13px}
                  </style>
                </head>
                <body><main>%s<footer>GRU Community Release</footer></main></body>
                </html>
                """.formatted(escape(title), content);
    }

    private String escape(String value) {
        return value
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }
}
