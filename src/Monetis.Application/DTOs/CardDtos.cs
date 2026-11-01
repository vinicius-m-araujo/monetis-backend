namespace Monetis.Application.DTOs;

public record CardResponse(Guid Id, string Name);
public record CreateCardRequest(string Name);
public record UpdateCardRequest(string Name);
