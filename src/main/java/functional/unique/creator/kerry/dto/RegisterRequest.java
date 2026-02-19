package functional.unique.creator.kerry.dto;

import org.springframework.web.multipart.MultipartFile;

public class RegisterRequest {
    public String phone;
    public String nickname;
    public String password;
    public MultipartFile avatar;
}
