package ai.limitless.arkgum.lifelog;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/**
 * Persisted lifelog. Mirrors the payload synced from the iOS app. {@code id} is the
 * Limitless-assigned id, so re-sends of the same lifelog upsert rather than duplicate.
 * The structured transcript is stored verbatim as JSON text in {@code contentsJson}.
 */
@Entity
@Table(name = "lifelog")
public class LifelogEntity {

    @Id
    @Column(nullable = false, updatable = false)
    private String id;

    @Column(nullable = false)
    private String title = "";

    @Column(columnDefinition = "text")
    private String markdown;

    private Instant startTime;
    private Instant endTime;

    @Column(nullable = false)
    private boolean starred;

    private Instant updatedAt;

    @Column(columnDefinition = "text")
    private String contentsJson;

    /** When this server received the record. */
    @Column(nullable = false)
    private Instant receivedAt;

    protected LifelogEntity() {
    }

    public LifelogEntity(String id) {
        this.id = id;
    }

    public String getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title == null ? "" : title;
    }

    public String getMarkdown() {
        return markdown;
    }

    public void setMarkdown(String markdown) {
        this.markdown = markdown;
    }

    public Instant getStartTime() {
        return startTime;
    }

    public void setStartTime(Instant startTime) {
        this.startTime = startTime;
    }

    public Instant getEndTime() {
        return endTime;
    }

    public void setEndTime(Instant endTime) {
        this.endTime = endTime;
    }

    public boolean isStarred() {
        return starred;
    }

    public void setStarred(boolean starred) {
        this.starred = starred;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }

    public String getContentsJson() {
        return contentsJson;
    }

    public void setContentsJson(String contentsJson) {
        this.contentsJson = contentsJson;
    }

    public Instant getReceivedAt() {
        return receivedAt;
    }

    public void setReceivedAt(Instant receivedAt) {
        this.receivedAt = receivedAt;
    }
}
