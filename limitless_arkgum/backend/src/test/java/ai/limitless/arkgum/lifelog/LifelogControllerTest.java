package ai.limitless.arkgum.lifelog;

import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "sync.token=test-secret")
class LifelogControllerTest {

    @Autowired
    private MockMvc mockMvc;

    private static final String BODY = """
            [
              {
                "id": "log-1",
                "title": "Standup",
                "markdown": "# notes",
                "startTime": "2026-07-17T09:00:00Z",
                "endTime": "2026-07-17T09:15:00Z",
                "isStarred": true,
                "updatedAt": "2026-07-17T09:16:00Z",
                "contents": [{"type": "heading1", "content": "Standup"}]
              }
            ]
            """;

    @Test
    void rejectsMissingToken() throws Exception {
        mockMvc.perform(post("/api/lifelogs")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(BODY))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void upsertIsIdempotentById() throws Exception {
        // First send: inserted.
        mockMvc.perform(post("/api/lifelogs")
                        .header("X-Sync-Token", "test-secret")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(BODY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.received", is(1)))
                .andExpect(jsonPath("$.inserted", is(1)))
                .andExpect(jsonPath("$.updated", is(0)));

        // Same id again: updated, not duplicated.
        mockMvc.perform(post("/api/lifelogs")
                        .header("X-Sync-Token", "test-secret")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(BODY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.inserted", is(0)))
                .andExpect(jsonPath("$.updated", is(1)));

        mockMvc.perform(get("/api/lifelogs/count").header("X-Sync-Token", "test-secret"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", is(1)));
    }
}
