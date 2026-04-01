package functional.unique.creator.kerry.dto;

import lombok.Data;

@Data
public class LoginRequest {
    private String phone;

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
    }

    public String getPassword() {
        return password;
    }

    private String password;

    public LoginRequest(String phone, String password) {

    }

    public void setPassword(String password) {
    }
}

