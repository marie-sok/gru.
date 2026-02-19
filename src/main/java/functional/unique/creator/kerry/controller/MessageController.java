package functional.unique.creator.kerry.controller;

import functional.unique.creator.kerry.model.Message;
import functional.unique.creator.kerry.model.User;
import functional.unique.creator.kerry.repository.MessageRepository;
import functional.unique.creator.kerry.repository.UserRepository;
import functional.unique.creator.kerry.security.JwtUtil;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.JwtException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/messages")
public class MessageController {

    private final MessageRepository messageRepo;
    private final UserRepository userRepo;
    private final JwtUtil jwtUtil;

    public MessageController(MessageRepository messageRepo,
                             UserRepository userRepo,
                             JwtUtil jwtUtil) {
        this.messageRepo = messageRepo;
        this.userRepo = userRepo;
        this.jwtUtil = jwtUtil;
    }

    @GetMapping("/history")
    public List<Message> getHistory(@RequestParam Long withUserId,
                                    @RequestHeader("Authorization") String tokenHeader) {
        String token = extractToken(tokenHeader);
        User user = validateAndGetUser(token);
        if (user == null) return List.of();

        return messageRepo.findTop50BySenderIdAndReceiverIdOrSenderIdAndReceiverIdOrderByTimestampAsc(
                user.getId(), withUserId, withUserId, user.getId()
        );
    }

    @PostMapping("/avatar")
    public String updateAvatar(@RequestParam MultipartFile avatar,
                               @RequestHeader("Authorization") String tokenHeader) throws IOException {
        String token = extractToken(tokenHeader);
        User user = validateAndGetUser(token);
        if (user == null) return "Invalid token";

        if (avatar != null && !avatar.isEmpty()) {
            String avatarDir = "avatars/";
            File dir = new File(avatarDir);
            if (!dir.exists()) dir.mkdirs();

            String filePath = "%s%s_%s".formatted(avatarDir, user.getPhone(), avatar.getOriginalFilename());
            avatar.transferTo(new File(filePath));

            user.setAvatarUrl(filePath);
            userRepo.save(user);

            return filePath;
        }
        return "No file uploaded";
    }

    private String extractToken(String header) {
        if (header != null && header.startsWith("Bearer ")) {
            return header.substring(7);
        }
        return null;
    }

    private User validateAndGetUser(String token) {
        try {
            if (token == null) return null;
            Jws<Claims> claims = jwtUtil.validateToken(token);
            String phone = claims.getBody().getSubject();
            Optional<User> u = userRepo.findByPhone(phone);
            return u.orElse(null);
        } catch (JwtException e) {
            return null;
        }
    }
}
